<?php
session_start();

// Check if Dropbox is configured
$dropbox_configured = file_exists('/home/camerabridge/.config/rclone/rclone.conf') &&
                      strpos(@file_get_contents('/home/camerabridge/.config/rclone/rclone.conf'), '[dropbox]') !== false;

$message = '';

// Handle Dropbox token submission
if (isset($_POST['dropbox_token'])) {
    $token = trim($_POST['dropbox_token']);

    if (!empty($token)) {
        // Create rclone configuration
        $config = "[dropbox]\n";
        $config .= "type = dropbox\n";
        $config .= 'token = {"access_token":"' . $token . '","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}' . "\n";

        // Write to temporary file
        file_put_contents('/tmp/rclone.conf', $config);

        // Copy to proper location using sudo
        exec('sudo cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
        exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf 2>&1');

        if ($return_code == 0) {
            $message = '<div class="alert success">✅ Dropbox configured successfully!</div>';
            $dropbox_configured = true;

            // Start camera-bridge service
            exec('sudo systemctl start camera-bridge 2>&1');
        } else {
            $message = '<div class="alert error">❌ Failed to save configuration. Please check permissions.</div>';
        }
    }
}

// Get system status
$ip_address = trim(shell_exec("hostname -I | awk '{print $1}'"));
$smb_running = trim(shell_exec("systemctl is-active smbd")) == "active";
$service_running = trim(shell_exec("systemctl is-active camera-bridge")) == "active";
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
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            max-width: 600px;
            width: 100%;
            padding: 40px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 32px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 16px;
        }
        .status-grid {
            display: grid;
            gap: 15px;
            margin-bottom: 30px;
        }
        .status-item {
            display: flex;
            align-items: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .status-item.success {
            background: #d4edda;
            color: #155724;
        }
        .status-item.error {
            background: #f8d7da;
            color: #721c24;
        }
        .status-icon {
            font-size: 24px;
            margin-right: 15px;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            color: #555;
            font-weight: 500;
        }
        input[type="text"], textarea {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e4e8;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input[type="text"]:focus, textarea:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        button:disabled {
            opacity: 0.5;
            cursor: not-allowed;
        }
        .alert {
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .alert.success {
            background: #d4edda;
            color: #155724;
            border: 1px solid #c3e6cb;
        }
        .alert.error {
            background: #f8d7da;
            color: #721c24;
            border: 1px solid #f5c6cb;
        }
        .info-box {
            background: #e8f4ff;
            border: 1px solid #b8e0ff;
            border-radius: 8px;
            padding: 15px;
            margin-top: 20px;
        }
        .info-box h3 {
            color: #0066cc;
            margin-bottom: 10px;
        }
        .info-box p {
            color: #333;
            line-height: 1.6;
        }
        code {
            background: #f6f8fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📷 Camera Bridge</h1>
        <p class="subtitle">Quick Setup & Status</p>

        <?php echo $message; ?>

        <div class="status-grid">
            <div class="status-item success">
                <span class="status-icon">✅</span>
                <div>
                    <strong>Network Connected</strong><br>
                    IP Address: <?php echo $ip_address; ?>
                </div>
            </div>

            <div class="status-item <?php echo $smb_running ? 'success' : 'error'; ?>">
                <span class="status-icon"><?php echo $smb_running ? '✅' : '❌'; ?></span>
                <div>
                    <strong>SMB File Sharing</strong><br>
                    <?php echo $smb_running ? 'Running' : 'Not running'; ?>
                </div>
            </div>

            <div class="status-item <?php echo $dropbox_configured ? 'success' : 'error'; ?>">
                <span class="status-icon"><?php echo $dropbox_configured ? '✅' : '⚠️'; ?></span>
                <div>
                    <strong>Dropbox</strong><br>
                    <?php echo $dropbox_configured ? 'Configured' : 'Not configured'; ?>
                </div>
            </div>

            <div class="status-item <?php echo $service_running ? 'success' : 'error'; ?>">
                <span class="status-icon"><?php echo $service_running ? '✅' : '⚠️'; ?></span>
                <div>
                    <strong>Camera Bridge Service</strong><br>
                    <?php echo $service_running ? 'Running' : 'Stopped'; ?>
                </div>
            </div>
        </div>

        <?php if (!$dropbox_configured): ?>
        <form method="post">
            <div class="form-group">
                <label for="dropbox_token">Dropbox Access Token</label>
                <textarea name="dropbox_token" id="dropbox_token" rows="3"
                    placeholder="Paste your Dropbox access token here" required></textarea>
                <small style="color: #666;">
                    You can get this from the Dropbox App Console or use the terminal UI to authenticate
                </small>
            </div>
            <button type="submit">Configure Dropbox</button>
        </form>
        <?php else: ?>
        <div class="alert success">
            <strong>System Ready!</strong><br>
            Your Camera Bridge is fully configured and ready to sync photos.
        </div>
        <?php endif; ?>

        <div class="info-box">
            <h3>📁 Network Share Access</h3>
            <p>
                <strong>Windows:</strong> <code>\\<?php echo $ip_address; ?>\photos</code><br>
                <strong>Mac/Linux:</strong> <code>smb://<?php echo $ip_address; ?>/photos</code><br>
                <strong>Credentials:</strong> Username: <code>camera</code> / Password: <code>camera123</code>
            </p>
        </div>

        <?php if ($service_running): ?>
        <div class="info-box" style="margin-top: 15px;">
            <h3>✨ How to Test</h3>
            <p>
                1. Connect to the network share using the credentials above<br>
                2. Drop any photo file into the share<br>
                3. Check your Dropbox - files appear in the <code>Camera-Photos</code> folder<br>
                4. View logs: <code>sudo journalctl -u camera-bridge -f</code>
            </p>
        </div>
        <?php endif; ?>
    </div>
</body>
</html>