<?php
/**
 * Advanced PII Redaction API
 * Handles file upload, processing, and redaction with comprehensive error handling
 */

class PIIRedactionAPI {
    private $config;
    private $allowedTypes;
    private $maxFileSize;
    private $uploadDir;
    private $tempDir;
    private $logFile;

    private function getProperExtension($originalExtension) {
    // Ensure extension has a dot prefix
    return strpos($originalExtension, '.') === 0 ? $originalExtension : '.' . $originalExtension;}
    
    public function __construct() {
        $this->config = $this->loadConfig();
        $this->allowedTypes = [
            'application/pdf',
            'application/msword',
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'text/plain',
            'image/jpeg',
            'image/png',
            'image/tiff',
            'image/bmp'
        ];
        $this->maxFileSize = 50 * 1024 * 1024; // 50MB
        $this->uploadDir = 'uploads/';
        $this->tempDir = 'temp/';
        $this->logFile = 'logs/redaction.log';
        
        $this->initializeDirs();
    }
    
    private function loadConfig() {
        $defaultConfig = [
            'python_path' => 'python',
            'redactor_script' => 'C:\Users\swapn\hackethon\AB2_10\PDF_IMG_to_TXT.py',
            'base_url' => 'https://f0bf004257d9.ngrok-free.app/',
            'cleanup_after_hours' => 24,
            'rate_limit_per_hour' => 100,
            'enable_analytics' => true
        ];
        
        $configFile = 'config.json';
        if (file_exists($configFile)) {
            $userConfig = json_decode(file_get_contents($configFile), true);
            return array_merge($defaultConfig, $userConfig);
        }
        
        return $defaultConfig;
    }
    
    private function initializeDirs() {
        $dirs = [$this->uploadDir, $this->tempDir, 'logs/', 'redacted/'];
        foreach ($dirs as $dir) {
            if (!file_exists($dir)) {
                mkdir($dir, 0755, true);
            }
        }
    }
    
    public function handleRequest() {
        try {
            // Enable CORS
            $this->setCorsHeaders();
            
            // Handle preflight requests
            if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
                http_response_code(200);
                exit;
            }
            
            // Rate limiting
            if (!$this->checkRateLimit()) {
                $this->sendErrorResponse('Rate limit exceeded. Please try again later.', 429);
                return;
            }
            
            // Validate request
            if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
                $this->sendErrorResponse('Only POST requests are allowed.', 405);
                return;
            }
            
            // Check if file was uploaded
            if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
                $this->sendErrorResponse('No file uploaded or upload error.', 400);
                return;
            }
            
            // Process the file
            $result = $this->processFile($_FILES['file']);
            
            if ($result['success']) {
                $this->sendSuccessResponse($result['data']);
            } else {
                $this->sendErrorResponse($result['error'], $result['code'] ?? 500);
            }
            
        } catch (Exception $e) {
            $this->logError('Unhandled exception: ' . $e->getMessage());
            $this->sendErrorResponse('Internal server error. Please try again.', 500);
        }
    }
    
    private function processFile($file) {
        try {
            // Validate file
            $validation = $this->validateFile($file);
            if (!$validation['valid']) {
                return ['success' => false, 'error' => $validation['error'], 'code' => 400];
            }
            
            // Generate unique filename
            $fileId = $this->generateFileId();
            $originalName = $file['name'];
            $extension = strtolower(pathinfo($originalName, PATHINFO_EXTENSION));
            $uploadedFile = $this->uploadDir . $fileId . '_original.' . $extension;
            
            // Move uploaded file
            if (!move_uploaded_file($file['tmp_name'], $uploadedFile)) {
                return ['success' => false, 'error' => 'Failed to save uploaded file.', 'code' => 500];
            }
            
            // Log file upload
            $this->logActivity('File uploaded', [
                'file_id' => $fileId,
                'original_name' => $originalName,
                'size' => $file['size'],
                'type' => $file['type']
            ]);
            
            // Process with Python redactor
            $redactionResult = $this->runRedaction($uploadedFile, $fileId);
            
            if (!$redactionResult['success']) {
                $this->cleanup($uploadedFile);
                return $redactionResult;
            }
            
            // Generate download URL
            $downloadUrl = $this->generateDownloadUrl($redactionResult['redacted_file']);
            
            // Schedule cleanup
            $this->scheduleCleanup($uploadedFile, $redactionResult['redacted_file']);
            
            return [
                'success' => true,
                'data' => [
                    'file_id' => $fileId,
                    'original_name' => $originalName,
                    'redacted_url' => $downloadUrl,
                    'processing_time' => $redactionResult['processing_time'],
                    'pii_found' => $redactionResult['pii_count'],
                    'file_size' => filesize($redactionResult['redacted_file']),
                    'expires_at' => date('Y-m-d H:i:s', time() + ($this->config['cleanup_after_hours'] * 3600))
                ]
            ];
            
        } catch (Exception $e) {
            $this->logError('File processing error: ' . $e->getMessage());
            return ['success' => false, 'error' => 'Processing failed. Please try again.', 'code' => 500];
        }
    }
    
    private function validateFile($file) {
        // Check file size
        if ($file['size'] > $this->maxFileSize) {
            return ['valid' => false, 'error' => 'File size exceeds maximum limit of ' . ($this->maxFileSize / 1024 / 1024) . 'MB'];
        }
        
        // Check file type
        $finfo = finfo_open(FILEINFO_MIME_TYPE);
        $mimeType = finfo_file($finfo, $file['tmp_name']);
        finfo_close($finfo);
        
        if (!in_array($mimeType, $this->allowedTypes)) {
            return ['valid' => false, 'error' => 'File type not supported. Supported types: PDF, Word, Excel, Text, Images'];
        }
        
        // Check file extension
        $extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
        $allowedExtensions = ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'png', 'jpg', 'jpeg', 'tiff', 'bmp'];
        
        if (!in_array($extension, $allowedExtensions)) {
            return ['valid' => false, 'error' => 'File extension not allowed'];
        }
        
        // Basic malware check (file signature)
        $handle = fopen($file['tmp_name'], 'rb');
        $signature = fread($handle, 4);
        fclose($handle);
        
        $maliciousSignatures = [
            "\x4D\x5A\x90\x00", // PE executable
            "\x50\x4B\x03\x04", // ZIP (could be malicious if unexpected)
        ];
        
        // Allow ZIP signature for Office documents
        if ($signature === "\x50\x4B\x03\x04" && !in_array($extension, ['docx', 'xlsx', 'pptx'])) {
            return ['valid' => false, 'error' => 'Suspicious file detected'];
        }
        
        return ['valid' => true];
    }
    
    private function runRedaction($inputFile, $fileId) {
        $startTime = microtime(true);
        
        // Prepare output file path
        $outputFile = 'redacted/' . $fileId . '_redacted.' . pathinfo($inputFile, PATHINFO_EXTENSION);
        
        // Build Python command
        $pythonScript = escapeshellarg($this->config['redactor_script']);
        $inputArg = escapeshellarg($inputFile);
        $outputArg = escapeshellarg($outputFile);
        
        $command = "{$this->config['python_path']} $pythonScript $inputArg $outputArg 2>&1";
        
        // Execute Python script
        $output = [];
        $returnCode = 0;
        exec($command, $output, $returnCode);
        
        $processingTime = round(microtime(true) - $startTime, 2);
        
        // Log command execution
        $this->logActivity('Python redaction executed', [
            'command' => $command,
            'return_code' => $returnCode,
            'output' => implode("\n", $output),
            'processing_time' => $processingTime
        ]);
        
        if ($returnCode !== 0) {
            return [
                'success' => false,
                'error' => 'Redaction processing failed: ' . implode("\n", $output),
                'code' => 500
            ];
        }
        
        // Verify output file exists
        if (!file_exists($outputFile)) {
            return [
                'success' => false,
                'error' => 'Redacted file was not created',
                'code' => 500
            ];
        }
        
        // Parse output for PII count (assume last line contains JSON with stats)
        $piiCount = 0;
        $lastLine = end($output);
        if ($lastLine && ($stats = json_decode($lastLine, true))) {
            $piiCount = $stats['total_pii_redacted'] ?? 0;
        }
        
        return [
            'success' => true,
            'redacted_file' => $outputFile,
            'processing_time' => $processingTime,
            'pii_count' => $piiCount
        ];
    }
    
    private function generateFileId() {
        return uniqid('pii_', true) . '_' . time();
    }
    
    private function generateDownloadUrl($filePath) {
        $fileName = basename($filePath);
        return $this->config['base_url'] . 'download.php?file=' . urlencode($fileName);
    }
    
    private function checkRateLimit() {
        $clientIP = $this->getClientIP();
        $rateLimitFile = $this->tempDir . 'rate_limit_' . md5($clientIP) . '.json';
        
        $currentHour = date('Y-m-d H');
        $requests = [];
        
        if (file_exists($rateLimitFile)) {
            $requests = json_decode(file_get_contents($rateLimitFile), true) ?: [];
        }
        
        // Clean old requests
        $requests = array_filter($requests, function($timestamp) use ($currentHour) {
            return substr($timestamp, 0, 13) === $currentHour;
        });
        
        // Check limit
        if (count($requests) >= $this->config['rate_limit_per_hour']) {
            return false;
        }
        
        // Add current request
        $requests[] = date('Y-m-d H:i:s');
        file_put_contents($rateLimitFile, json_encode($requests));
        
        return true;
    }
    
    private function getClientIP() {
        $ipKeys = ['HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_FORWARDED', 'HTTP_FORWARDED_FOR', 'HTTP_FORWARDED', 'REMOTE_ADDR'];
        
        foreach ($ipKeys as $key) {
            if (array_key_exists($key, $_SERVER) && !empty($_SERVER[$key])) {
                $ip = $_SERVER[$key];
                if (strpos($ip, ',') !== false) {
                    $ip = trim(explode(',', $ip)[0]);
                }
                if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_NO_PRIV_RANGE | FILTER_FLAG_NO_RES_RANGE)) {
                    return $ip;
                }
            }
        }
        
        return $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';
    }
    
    private function scheduleCleanup($originalFile, $redactedFile) {
        $cleanupTime = time() + ($this->config['cleanup_after_hours'] * 3600);
        $cleanupData = [
            'files' => [$originalFile, $redactedFile],
            'cleanup_time' => $cleanupTime
        ];
        
        $cleanupFile = $this->tempDir . 'cleanup_' . basename($originalFile) . '.json';
        file_put_contents($cleanupFile, json_encode($cleanupData));
    }
    
    private function cleanup($file) {
        if (file_exists($file)) {
            unlink($file);
        }
    }
    
    private function setCorsHeaders() {
        header('Access-Control-Allow-Origin: *');
        header('Access-Control-Allow-Methods: POST, OPTIONS');
        header('Access-Control-Allow-Headers: Content-Type, Authorization');
        header('Content-Type: application/json');
    }
    
    private function sendSuccessResponse($data) {
        echo json_encode([
            'success' => true,
            'data' => $data,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    private function sendErrorResponse($message, $code = 500) {
        http_response_code($code);
        echo json_encode([
            'success' => false,
            'error' => $message,
            'code' => $code,
            'timestamp' => date('Y-m-d H:i:s')
        ]);
    }
    
    private function logActivity($message, $data = []) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'ip' => $this->getClientIP(),
            'message' => $message,
            'data' => $data
        ];
        
        file_put_contents($this->logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    private function logError($message) {
        $this->logActivity('ERROR: ' . $message);
    }
    
    public function runCleanup() {
        $cleanupFiles = glob($this->tempDir . 'cleanup_*.json');
        $currentTime = time();
        
        foreach ($cleanupFiles as $cleanupFile) {
            $cleanupData = json_decode(file_get_contents($cleanupFile), true);
            
            if ($cleanupData && $currentTime >= $cleanupData['cleanup_time']) {
                foreach ($cleanupData['files'] as $file) {
                    $this->cleanup($file);
                }
                unlink($cleanupFile);
                $this->logActivity('Cleaned up expired files', $cleanupData);
            }
        }
    }
    
    public function getStats() {
        if (!$this->config['enable_analytics']) {
            return ['error' => 'Analytics disabled'];
        }
        
        $logs = file_exists($this->logFile) ? file($this->logFile, FILE_IGNORE_NEW_LINES) : [];
        $stats = [
            'total_requests' => 0,
            'successful_redactions' => 0,
            'errors' => 0,
            'today_requests' => 0,
            'file_types' => [],
            'hourly_distribution' => []
        ];
        
        $today = date('Y-m-d');
        
        foreach ($logs as $logLine) {
            $entry = json_decode($logLine, true);
            if (!$entry) continue;
            
            $stats['total_requests']++;
            
            if (strpos($entry['timestamp'], $today) === 0) {
                $stats['today_requests']++;
            }
            
            if (strpos($entry['message'], 'ERROR') === 0) {
                $stats['errors']++;
            } else if (strpos($entry['message'], 'File uploaded') !== false) {
                $stats['successful_redactions']++;
                
                if (isset($entry['data']['type'])) {
                    $type = $entry['data']['type'];
                    $stats['file_types'][$type] = ($stats['file_types'][$type] ?? 0) + 1;
                }
            }
            
            $hour = substr($entry['timestamp'], 11, 2);
            $stats['hourly_distribution'][$hour] = ($stats['hourly_distribution'][$hour] ?? 0) + 1;
        }
        
        return $stats;
    }
}

// Initialize and handle request
$api = new PIIRedactionAPI();

// Handle different endpoints
$requestUri = $_SERVER['REQUEST_URI'];
$path = parse_url($requestUri, PHP_URL_PATH);

switch ($path) {
    case '/upload':
    case '/api/upload':
        $api->handleRequest();
        break;
        
    case '/cleanup':
        if (php_sapi_name() === 'cli') {
            $api->runCleanup();
            echo "Cleanup completed\n";
        } else {
            http_response_code(403);
            echo json_encode(['error' => 'Cleanup endpoint only accessible via CLI']);
        }
        break;
        
    case '/stats':
        if (isset($_GET['key']) && $_GET['key'] === 'admin_stats_key') {
            echo json_encode($api->getStats());
        } else {
            http_response_code(403);
            echo json_encode(['error' => 'Access denied']);
        }
        break;
        
    default:
        $api->handleRequest();
        break;
}
?>