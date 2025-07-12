<?php
/**
 * Secure Download Handler for Redacted Files
 * Provides secure, time-limited downloads with proper headers
 */

class SecureDownloadHandler {
    private $redactedDir = 'redacted/';
    private $maxDownloadTime = 3600; // 1 hour
    private $logFile = 'logs/downloads.log';
    
    public function __construct() {
        if (!file_exists('logs/')) {
            mkdir('logs/', 0755, true);
        }
    }
    
    public function handleDownload() {
        try {
            // Validate request
            if (!isset($_GET['file']) || empty($_GET['file'])) {
                $this->sendError('File parameter missing', 400);
                return;
            }
            
            $requestedFile = $_GET['file'];
            
            // Sanitize filename
            $filename = $this->sanitizeFilename($requestedFile);
            if (!$filename) {
                $this->sendError('Invalid filename', 400);
                return;
            }
            
            // Check if file exists
            $filePath = $this->redactedDir . $filename;
            if (!file_exists($filePath)) {
                $this->sendError('File not found', 404);
                return;
            }
            
            // Check file age (security measure)
            $fileAge = time() - filemtime($filePath);
            if ($fileAge > $this->maxDownloadTime) {
                $this->sendError('File has expired', 410);
                return;
            }
            
            // Log download attempt
            $this->logDownload($filename, $this->getClientIP());
            
            // Serve file
            $this->serveFile($filePath, $filename);
            
        } catch (Exception $e) {
            $this->logError('Download error: ' . $e->getMessage());
            $this->sendError('Internal server error', 500);
        }
    }
    
    private function sanitizeFilename($filename) {
        // Remove path traversal attempts
        $filename = basename($filename);
        
        // Only allow specific patterns for redacted files
        // if (!preg_match('/^pii_[a-zA-Z0-9._-]+_redacted\.[a-zA-Z0-9]{2,5}$/', $filename)) {
        //     return false;
        // }
        
        // Additional security: check for double extensions
        // if (substr_count($filename, '.') > 1) {
        //     return false;
        // }
        
        return $filename;
    }
    
    private function serveFile($filePath, $filename) {
        // Get file info
        $fileSize = filesize($filePath);
        $mimeType = $this->getMimeType($filePath);
        
        // Set appropriate headers
        header('Content-Type: ' . $mimeType);
        header('Content-Length: ' . $fileSize);
        header('Content-Disposition: attachment; filename="' . $filename . '"');
        header('Cache-Control: no-cache, no-store, must-revalidate');
        header('Pragma: no-cache');
        header('Expires: 0');
        
        // Security headers
        header('X-Content-Type-Options: nosniff');
        header('X-Frame-Options: DENY');
        header('X-XSS-Protection: 1; mode=block');
        
        // Handle range requests for large files
        if ($fileSize > 1024 * 1024) { // Files > 1MB
            $this->handleRangeRequest($filePath, $fileSize);
        } else {
            // Simple file output
            readfile($filePath);
        }
        
        // Clean up after download (optional)
        $this->scheduleFileCleanup($filePath);
    }
    
    private function handleRangeRequest($filePath, $fileSize) {
        $range = $_SERVER['HTTP_RANGE'] ?? '';
        
        if (empty($range)) {
            // No range request, serve entire file
            readfile($filePath);
            return;
        }
        
        // Parse range header
        if (!preg_match('/bytes=(\d+)-(\d+)?/', $range, $matches)) {
            header('HTTP/1.1 416 Requested Range Not Satisfiable');
            return;
        }
        
        $start = intval($matches[1]);
        $end = isset($matches[2]) ? intval($matches[2]) : $fileSize - 1;
        
        // Validate range
        if ($start > $end || $start >= $fileSize || $end >= $fileSize) {
            header('HTTP/1.1 416 Requested Range Not Satisfiable');
            return;
        }
        
        // Send partial content
        header('HTTP/1.1 206 Partial Content');
        header("Content-Range: bytes $start-$end/$fileSize");
        header('Content-Length: ' . ($end - $start + 1));
        
        // Output file chunk
        $file = fopen($filePath, 'rb');
        fseek($file, $start);
        $remaining = $end - $start + 1;
        
        while ($remaining > 0 && !feof($file)) {
            $chunkSize = min(8192, $remaining);
            echo fread($file, $chunkSize);
            $remaining -= $chunkSize;
        }
        
        fclose($file);
    }
    
    private function getMimeType($filePath) {
        $extension = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        
        $mimeTypes = [
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls' => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'txt' => 'text/plain',
            'png' => 'image/png',
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'tiff' => 'image/tiff',
            'bmp' => 'image/bmp'
        ];
        
        return $mimeTypes[$extension] ?? 'application/octet-stream';
    }
    
    private function scheduleFileCleanup($filePath) {
        // Mark file for cleanup after successful download
        $cleanupFile = 'temp/cleanup_' . basename($filePath) . '_' . time() . '.flag';
        file_put_contents($cleanupFile, $filePath);
    }
    
    private function getClientIP() {
        $ipKeys = ['HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR'];
        
        foreach ($ipKeys as $key) {
            if (array_key_exists($key, $_SERVER) && !empty($_SERVER[$key])) {
                $ip = $_SERVER[$key];
                if (strpos($ip, ',') !== false) {
                    $ip = trim(explode(',', $ip)[0]);
                }
                return $ip;
            }
        }
        
        return '0.0.0.0';
    }
    
    private function logDownload($filename, $ip) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'ip' => $ip,
            'filename' => $filename,
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'Unknown'
        ];
        
        file_put_contents($this->logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    private function logError($message) {
        $logEntry = [
            'timestamp' => date('Y-m-d H:i:s'),
            'ip' => $this->getClientIP(),
            'error' => $message
        ];
        
        file_put_contents($this->logFile, json_encode($logEntry) . "\n", FILE_APPEND | LOCK_EX);
    }
    
    private function sendError($message, $code) {
        http_response_code($code);
        echo json_encode([
            'error' => $message,
            'code' => $code
        ]);
    }
}

// Handle download request
$handler = new SecureDownloadHandler();
$handler->handleDownload();
?>