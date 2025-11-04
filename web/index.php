<?php
session_start();
$message = '';
// Skip WiFi setup and go directly to Dropbox token entry
$current_step = $_GET['step'] ?? 'dropbox';

// Check configuration status
function check_wifi_configured() {
    return file_exists('/etc/wpa_supplicant/wpa_supplicant.conf') &&
           filesize('/etc/wpa_supplicant/wpa_supplicant.conf') > 100;
}

function check_dropbox_configured() {
    return file_exists('/home/camerabridge/.config/rclone/rclone.conf') &&
           strpos(file_get_contents('/home/camerabridge/.config/rclone/rclone.conf'), '[dropbox]') !== false;
}

$wifi_configured = check_wifi_configured();
$dropbox_configured = check_dropbox_configured();

// Handle form submissions
if (isset($_POST['submit'])) {
    if ($_POST['submit'] == 'dropbox_token') {
        $token_input = trim($_POST['dropbox_token']);

        if (!empty($token_input)) {
            // Detect token format
            $is_oauth2 = false;
            $token_json = '';

            // Check if it's JSON (OAuth2 format)
            if (strpos($token_input, '{') !== false && strpos($token_input, '}') !== false) {
                // OAuth2 token - validate JSON
                $token_data = json_decode($token_input, true);
                if (json_last_error() === JSON_ERROR_NONE && isset($token_data['access_token'])) {
                    $is_oauth2 = true;
                    $token_json = $token_input;
                    $has_refresh = isset($token_data['refresh_token']);

                    if ($has_refresh) {
                        $message = '<div class="success">OAuth2 token detected with refresh capability!</div>';
                    } else {
                        $message = '<div class="warning">OAuth2 token detected but no refresh token found.</div>';
                    }
                }
            }

            // If not OAuth2, treat as legacy token
            if (!$is_oauth2) {
                // Legacy token format (just the access token string)
                if (strpos($token_input, 'sl.') === 0) {
                    // Create JSON format for legacy token
                    $token_json = json_encode([
                        'access_token' => $token_input,
                        'token_type' => 'bearer',
                        'expiry' => '0001-01-01T00:00:00Z'
                    ]);
                    $message = '<div class="warning">Legacy token format detected. Consider using OAuth2 for auto-refresh.</div>';
                } else {
                    $message = '<div class="error">Invalid token format. Please provide either an OAuth2 JSON token or a legacy token starting with "sl."</div>';
                }
            }

            if ($token_json) {
                // Create rclone configuration
                $config = "[dropbox]\n";
                $config .= "type = dropbox\n";
                $config .= "token = $token_json\n";

                // Create directory and write config
                exec('sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone 2>&1', $output);

                // Write to temp file first
                $temp_file = '/tmp/rclone_config_' . time() . '.conf';
                file_put_contents($temp_file, $config);

                // Copy to final location
                exec('sudo cp ' . escapeshellarg($temp_file) . ' /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output);
                exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output);
                exec('sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output);

                // Test connection
                exec('timeout 30 sudo -u camerabridge rclone lsd dropbox: 2>&1', $output, $return_code);

                if ($return_code == 0) {
                    if ($is_oauth2 && isset($has_refresh) && $has_refresh) {
                        $message = '<div class="success">✅ Dropbox configured successfully with OAuth2 auto-refresh!</div>';
                    } else {
                        $message = '<div class="success">✅ Dropbox configured successfully!</div>';
                    }
                    $dropbox_configured = true;
                    $current_step = 'complete';
                } else {
                    $message = '<div class="error">Failed to connect to Dropbox. Error: ' . implode(' ', $output) . '</div>';

                    // Additional debug info
                    $message .= '<div class="info-box"><strong>Debug Info:</strong><br>';
                    $message .= 'Token type: ' . ($is_oauth2 ? 'OAuth2' : 'Legacy') . '<br>';
                    $message .= 'Has refresh: ' . (isset($has_refresh) && $has_refresh ? 'Yes' : 'No') . '<br>';
                    $message .= 'Config file exists: ' . (file_exists('/home/camerabridge/.config/rclone/rclone.conf') ? 'Yes' : 'No') . '<br>';
                    $message .= '</div>';
                }

                // Clean up temp file
                unlink($temp_file);
            }
        } else {
            $message = '<div class="error">Please provide a valid Dropbox token.</div>';
        }

    } elseif ($_POST['submit'] == 'finish_setup') {
        // Start camera bridge service
        exec('sudo systemctl enable camera-bridge 2>/dev/null || sudo /opt/camera-bridge/scripts/camera-bridge-service.sh start &');
        exec('sudo systemctl enable smbd nmbd');
        exec('sudo systemctl start smbd nmbd');

        $message = '<div class="success">Setup complete! Your Camera Bridge is now ready to use.</div>';

        // Redirect to status page after a delay
        echo '<script>setTimeout(function(){ window.location.href="status.php"; }, 5000);</script>';
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Camera Bridge Setup</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px 30px;
            text-align: center;
        }
        .header h1 {
            font-size: 2em;
            margin-bottom: 10px;
        }
        .header p {
            font-size: 1.1em;
            opacity: 0.9;
        }
        .progress-bar {
            display: flex;
            padding: 30px 30px 0;
        }
        .progress-step {
            flex: 1;
            text-align: center;
            position: relative;
        }
        .progress-step::before {
            content: '';
            position: absolute;
            top: 15px;
            left: 50%;
            right: -50%;
            height: 2px;
            background: #e0e0e0;
            z-index: 0;
        }
        .progress-step:last-child::before { display: none; }
        .progress-step.active::before { background: #667eea; }
        .progress-step.completed::before { background: #4caf50; }
        .progress-number {
            width: 30px;
            height: 30px;
            background: #e0e0e0;
            border-radius: 50%;
            display: flex;
            justify-content: center;
            align-items: center;
            margin: 0 auto 10px;
            font-weight: bold;
            color: #999;
            position: relative;
            z-index: 1;
        }
        .progress-step.active .progress-number {
            background: #667eea;
            color: white;
        }
        .progress-step.completed .progress-number {
            background: #4caf50;
            color: white;
        }
        .progress-label {
            font-size: 0.9em;
            color: #666;
        }
        .content {
            padding: 30px;
        }
        .form-group {
            margin-bottom: 25px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }
        input[type="text"],
        input[type="password"],
        select,
        textarea {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 1em;
            transition: border-color 0.3s;
        }
        input:focus,
        select:focus,
        textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        textarea {
            resize: vertical;
            min-height: 120px;
            font-family: monospace;
            font-size: 0.95em;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 15px 30px;
            border-radius: 10px;
            font-size: 1.1em;
            font-weight: 500;
            cursor: pointer;
            width: 100%;
            transition: transform 0.3s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            background: #ccc;
            cursor: not-allowed;
            transform: none;
        }
        .button-group {
            display: flex;
            gap: 10px;
        }
        .button-secondary {
            background: #f5f5f5;
            color: #333;
        }
        .button-secondary:hover {
            background: #e0e0e0;
        }
        .success {
            background: #d4edda;
            color: #155724;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #28a745;
        }
        .error {
            background: #f8d7da;
            color: #721c24;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #dc3545;
        }
        .warning {
            background: #fff3cd;
            color: #856404;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #ffc107;
        }
        .info-box {
            background: #e7f3ff;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
            border-left: 4px solid #2196f3;
        }
        .status-grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin: 20px 0;
        }
        .status-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .status-icon {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        .status-title {
            font-weight: 600;
            color: #333;
            margin-bottom: 5px;
        }
        .status-value {
            color: #666;
            font-size: 0.9em;
        }
        .success-icon { color: #4caf50; }
        .pending-icon { color: #ff9800; }
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
            vertical-align: middle;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .help-text {
            font-size: 0.85em;
            color: #666;
            margin-top: 5px;
        }
        .token-type-indicator {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            margin-left: 10px;
        }
        .oauth2-indicator {
            background: #d4edda;
            color: #155724;
        }
        .legacy-indicator {
            background: #fff3cd;
            color: #856404;
        }
        .code-example {
            background: #263238;
            color: #aed581;
            padding: 10px;
            border-radius: 6px;
            font-family: monospace;
            font-size: 0.85em;
            overflow-x: auto;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📷 Camera Bridge</h1>
            <p>Professional Photo Sync System</p>
            <div style="margin-top: 15px; font-size: 1.1em; background: rgba(255,255,255,0.15); padding: 10px 20px; border-radius: 10px; display: inline-block;">
                <strong>🌐 Access this device at:</strong> <?php echo $_SERVER['SERVER_ADDR']; ?>
            </div>
        </div>

        <div class="progress-bar">
            <div class="progress-step <?php echo $current_step == 'dropbox' ? 'active' : ($dropbox_configured ? 'completed' : ''); ?>">
                <div class="progress-number">1</div>
                <div class="progress-label">Dropbox</div>
            </div>
            <div class="progress-step <?php echo $current_step == 'complete' ? 'active' : ''; ?>">
                <div class="progress-number">2</div>
                <div class="progress-label">Complete</div>
            </div>
        </div>

        <div class="content">
            <?php echo $message; ?>

            <?php if ($current_step == 'dropbox'): ?>
                <h2>Connect to Dropbox</h2>
                <p style="margin-bottom: 20px;">Enter your Dropbox token to enable automatic photo synchronization.</p>

                <div class="info-box">
                    <strong>📌 Two ways to get your token:</strong>

                    <div style="margin-top: 15px;">
                        <strong>Option 1: OAuth2 Token (Recommended)</strong>
                        <span class="token-type-indicator oauth2-indicator">Auto-Refresh</span>
                    </div>
                    <ol style="margin-top: 10px; margin-left: 20px;">
                        <li>On a computer with browser, run: <code style="background: #f0f0f0; padding: 2px 6px; border-radius: 4px;">rclone authorize dropbox</code></li>
                        <li>Log in to Dropbox when browser opens</li>
                        <li>Copy the ENTIRE JSON output (with {} brackets)</li>
                    </ol>

                    <div class="code-example">
                    {"access_token":"sl.xxx...","token_type":"bearer","refresh_token":"xxx...","expiry":"2025-01-01T00:00:00Z"}
                    </div>

                    <div style="margin-top: 20px;">
                        <strong>Option 2: Legacy Token</strong>
                        <span class="token-type-indicator legacy-indicator">May Expire</span>
                    </div>
                    <ol style="margin-top: 10px; margin-left: 20px;">
                        <li>Visit <a href="https://www.dropbox.com/developers/apps" target="_blank">Dropbox App Console</a></li>
                        <li>Create app with "Full Dropbox" access</li>
                        <li>Generate access token</li>
                        <li>Copy token (starts with "sl.")</li>
                    </ol>
                </div>

                <form method="POST">
                    <div class="form-group">
                        <label for="dropbox_token">Dropbox Token (OAuth2 JSON or Legacy)</label>
                        <textarea
                            name="dropbox_token"
                            id="dropbox_token"
                            placeholder="Paste either:&#10;1. Complete OAuth2 JSON: {&quot;access_token&quot;:&quot;...&quot;,&quot;refresh_token&quot;:&quot;...&quot;}&#10;2. Legacy token: sl.xxxxx..."
                            required></textarea>
                        <div class="help-text">
                            ✅ Accepts both OAuth2 JSON (with auto-refresh) and legacy tokens<br>
                            ✅ OAuth2 tokens never expire | Legacy tokens may need renewal
                        </div>
                    </div>
                    <button type="submit" name="submit" value="dropbox_token">Connect to Dropbox</button>
                </form>

            <?php elseif ($current_step == 'complete'): ?>
                <h2>✅ Setup Complete!</h2>
                <p style="margin-bottom: 20px;">Your Camera Bridge is now configured and ready to use.</p>

                <div class="status-grid">
                    <div class="status-card">
                        <div class="status-icon success-icon">✓</div>
                        <div class="status-title">Dropbox</div>
                        <div class="status-value">Connected</div>
                    </div>
                    <div class="status-card">
                        <div class="status-icon success-icon">✓</div>
                        <div class="status-title">Service</div>
                        <div class="status-value">Ready</div>
                    </div>
                </div>

                <div class="info-box">
                    <strong>📸 Next Steps:</strong>
                    <ul style="margin-top: 10px; margin-left: 20px;">
                        <li>Connect your camera via USB or insert SD card</li>
                        <li>Photos will automatically sync to your Dropbox</li>
                        <li>Access network share at: \\<?php echo $_SERVER['SERVER_ADDR']; ?>\camera-share</li>
                        <li>Default credentials: camera / camera123</li>
                    </ul>
                </div>

                <form method="POST">
                    <button type="submit" name="submit" value="finish_setup">Start Camera Bridge Service</button>
                </form>
            <?php endif; ?>
        </div>
    </div>
</body>
</html>