<?php
session_start();
$message = '';
$current_step = $_GET['step'] ?? 'wifi';

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
    if ($_POST['submit'] == 'wifi') {
        $ssid = escapeshellarg($_POST['ssid']);
        $password = escapeshellarg($_POST['password']);

        // Generate WPA supplicant configuration
        $config = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n";
        $config .= "update_config=1\n";
        $config .= "country=US\n\n";
        $config .= "network={\n";
        $config .= "    ssid=" . $ssid . "\n";
        $config .= "    psk=" . $password . "\n";
        $config .= "    key_mgmt=WPA-PSK\n";
        $config .= "    priority=1\n";
        $config .= "}\n";

        // Write temporary config file
        file_put_contents('/tmp/wpa_supplicant.conf', $config);

        // Use WiFi manager to connect
        exec('sudo /opt/camera-bridge/scripts/wifi-manager.sh connect ' . $ssid . ' ' . $password . ' 2>&1', $output, $return_code);

        if ($return_code == 0) {
            $message = '<div class="success">WiFi configured successfully! Please proceed to Dropbox setup.</div>';
            $wifi_configured = true;
            $current_step = 'dropbox';
        } else {
            $message = '<div class="error">Failed to connect to WiFi. Please check your credentials and try again.</div>';
        }

    } elseif ($_POST['submit'] == 'dropbox_token') {
        $token = trim($_POST['dropbox_token']);

        if (!empty($token)) {
            // Create rclone configuration
            $config = "[dropbox]\n";
            $config .= "type = dropbox\n";
            $config .= "token = {\"access_token\":\"$token\",\"token_type\":\"bearer\",\"expiry\":\"0001-01-01T00:00:00Z\"}\n";

            // Create directory and write config
            exec('sudo -u camerabridge mkdir -p /home/camerabridge/.config/rclone');
            file_put_contents('/tmp/rclone.conf', $config);
            exec('sudo cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf');
            exec('sudo chown camerabridge:camerabridge /home/camerabridge/.config/rclone/rclone.conf');
            exec('sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf');

            // Test connection
            exec('sudo -u camerabridge rclone lsd dropbox: 2>&1', $output, $return_code);

            if ($return_code == 0) {
                $message = '<div class="success">Dropbox configured successfully!</div>';
                $dropbox_configured = true;
                $current_step = 'complete';
            } else {
                $message = '<div class="error">Failed to connect to Dropbox. Please check your token and try again.</div>';
            }

            // Clean up temp file
            unlink('/tmp/rclone.conf');
        } else {
            $message = '<div class="error">Please provide a valid Dropbox token.</div>';
        }

    } elseif ($_POST['submit'] == 'finish_setup') {
        // Start camera bridge service
        exec('sudo systemctl enable camera-bridge 2>/dev/null || sudo /opt/camera-bridge/scripts/camera-bridge-service.sh start &');
        exec('sudo systemctl enable smbd nmbd');
        exec('sudo systemctl start smbd nmbd');

        $message = '<div class="success">Setup complete! Your Camera Bridge is now ready to use.</div>';

        // Optional: redirect to status page after a delay
        echo '<script>setTimeout(function(){ window.location.href="status.php"; }, 5000);</script>';
    }
}

// Get available WiFi networks for the current step
$available_networks = array();
if ($current_step == 'wifi') {
    exec('sudo iwlist wlan0 scan 2>/dev/null | grep ESSID', $networks);
    foreach ($networks as $network) {
        if (preg_match('/ESSID:"(.+)"/', $network, $matches) && !empty($matches[1])) {
            $available_networks[] = $matches[1];
        }
    }
    $available_networks = array_unique($available_networks);
    sort($available_networks);
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Camera Bridge Setup</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen', 'Ubuntu', 'Cantarell', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
            padding: 20px;
        }

        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.1);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
            padding: 40px;
            text-align: center;
            color: white;
        }

        .header h1 {
            font-size: 2.5rem;
            font-weight: 300;
            margin-bottom: 10px;
        }

        .header .subtitle {
            font-size: 1.2rem;
            opacity: 0.9;
        }

        .content {
            padding: 40px;
        }

        .progress {
            display: flex;
            margin-bottom: 40px;
            background: #f8f9fa;
            border-radius: 50px;
            overflow: hidden;
            box-shadow: inset 0 2px 4px rgba(0,0,0,0.05);
        }

        .step {
            flex: 1;
            text-align: center;
            padding: 20px;
            font-weight: 600;
            transition: all 0.3s ease;
            position: relative;
        }

        .step:not(:last-child)::after {
            content: '';
            position: absolute;
            right: 0;
            top: 50%;
            transform: translateY(-50%);
            width: 1px;
            height: 30px;
            background: #dee2e6;
        }

        .step.active {
            background: #007bff;
            color: white;
            box-shadow: 0 4px 15px rgba(0, 123, 255, 0.3);
        }

        .step.completed {
            background: #28a745;
            color: white;
        }

        .step.completed::before {
            content: '✓ ';
            font-weight: bold;
        }

        .form-section {
            margin-bottom: 30px;
        }

        .form-section h2 {
            color: #2c3e50;
            margin-bottom: 20px;
            font-size: 1.8rem;
            font-weight: 500;
        }

        .form-group {
            margin-bottom: 25px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #34495e;
            font-size: 1rem;
        }

        input, select, textarea {
            width: 100%;
            padding: 15px 20px;
            border: 2px solid #e9ecef;
            border-radius: 12px;
            font-size: 16px;
            transition: all 0.3s ease;
            background: #fff;
        }

        input:focus, select:focus, textarea:focus {
            outline: none;
            border-color: #007bff;
            box-shadow: 0 0 0 3px rgba(0, 123, 255, 0.1);
            transform: translateY(-2px);
        }

        button {
            background: linear-gradient(135deg, #007bff, #0056b3);
            color: white;
            padding: 18px 40px;
            border: none;
            border-radius: 12px;
            cursor: pointer;
            font-size: 16px;
            font-weight: 600;
            transition: all 0.3s ease;
            width: 100%;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        button:hover {
            transform: translateY(-3px);
            box-shadow: 0 10px 25px rgba(0, 123, 255, 0.3);
        }

        button:active {
            transform: translateY(-1px);
        }

        .success {
            background: linear-gradient(135deg, #d4edda, #c3e6cb);
            color: #155724;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 25px;
            border-left: 5px solid #28a745;
            font-weight: 500;
        }

        .error {
            background: linear-gradient(135deg, #f8d7da, #f1b0b7);
            color: #721c24;
            padding: 20px;
            border-radius: 12px;
            margin-bottom: 25px;
            border-left: 5px solid #dc3545;
            font-weight: 500;
        }

        .instructions {
            background: linear-gradient(135deg, #e3f2fd, #bbdefb);
            padding: 30px;
            border-radius: 12px;
            margin: 25px 0;
            border-left: 5px solid #2196f3;
        }

        .instructions h3 {
            margin-top: 0;
            margin-bottom: 15px;
            color: #1565c0;
            font-size: 1.3rem;
        }

        .instructions ol {
            margin: 15px 0;
            padding-left: 25px;
        }

        .instructions li {
            margin-bottom: 12px;
            line-height: 1.6;
        }

        .instructions a {
            color: #1976d2;
            text-decoration: none;
            font-weight: 600;
        }

        .instructions a:hover {
            text-decoration: underline;
        }

        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin: 25px 0;
        }

        .status-item {
            padding: 25px;
            background: #f8f9fa;
            border-radius: 12px;
            text-align: center;
            transition: all 0.3s ease;
        }

        .status-item:hover {
            transform: translateY(-5px);
            box-shadow: 0 10px 25px rgba(0,0,0,0.1);
        }

        .status-item.success {
            background: linear-gradient(135deg, #d4edda, #c3e6cb);
            color: #155724;
            border: 2px solid #28a745;
        }

        .status-item h4 {
            margin: 0 0 15px 0;
            font-size: 1.2rem;
            font-weight: 600;
        }

        .status-item p {
            margin: 0;
            font-size: 1.1rem;
            font-weight: 500;
        }

        .footer {
            background: #f8f9fa;
            padding: 30px;
            text-align: center;
            color: #6c757d;
            border-top: 1px solid #dee2e6;
        }

        .footer a {
            color: #007bff;
            text-decoration: none;
        }

        .icon {
            font-size: 1.5rem;
            margin-right: 10px;
            vertical-align: middle;
        }

        .feature-list {
            list-style: none;
            padding-left: 0;
        }

        .feature-list li {
            padding: 10px 0;
            border-bottom: 1px solid #e9ecef;
        }

        .feature-list li:before {
            content: '✓';
            color: #28a745;
            font-weight: bold;
            margin-right: 15px;
        }

        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { border-radius: 15px; }
            .header { padding: 30px 20px; }
            .header h1 { font-size: 2rem; }
            .content { padding: 30px 20px; }
            .progress { flex-direction: column; }
            .step { border-radius: 0; }
            .step:not(:last-child)::after { display: none; }
            .status-grid { grid-template-columns: 1fr; }
            button { padding: 15px 30px; }
        }

        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #007bff;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }

        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1><span class="icon">📷</span>Camera Bridge</h1>
            <p class="subtitle">Automatic Photo Sync System Setup</p>
        </div>

        <div class="content">
            <div class="progress">
                <div class="step <?php echo $wifi_configured ? 'completed' : ($current_step == 'wifi' ? 'active' : ''); ?>">
                    WiFi Setup
                </div>
                <div class="step <?php echo $dropbox_configured ? 'completed' : ($current_step == 'dropbox' ? 'active' : ''); ?>">
                    Dropbox Setup
                </div>
                <div class="step <?php echo ($current_step == 'complete' ? 'active' : ''); ?>">
                    Complete
                </div>
            </div>

            <?php echo $message; ?>

            <?php if ($current_step == 'wifi'): ?>
                <div class="form-section">
                    <h2><span class="icon">🌐</span>WiFi Configuration</h2>

                    <form method="POST" id="wifi-form">
                        <div class="form-group">
                            <label for="ssid">Select Your WiFi Network:</label>
                            <select name="ssid" id="ssid" required>
                                <option value="">Choose your network...</option>
                                <?php foreach ($available_networks as $network): ?>
                                    <option value="<?php echo htmlspecialchars($network); ?>">
                                        <?php echo htmlspecialchars($network); ?>
                                    </option>
                                <?php endforeach; ?>
                                <option value="manual">Enter network manually...</option>
                            </select>
                        </div>

                        <div class="form-group" id="manual-ssid" style="display: none;">
                            <label for="manual_ssid_input">Network Name (SSID):</label>
                            <input type="text" id="manual_ssid_input" placeholder="Enter network name">
                        </div>

                        <div class="form-group">
                            <label for="password">WiFi Password:</label>
                            <input type="password" name="password" id="password" required
                                   placeholder="Enter your WiFi password">
                        </div>

                        <button type="submit" name="submit" value="wifi" id="wifi-submit">
                            Connect to WiFi
                        </button>
                    </form>
                </div>

                <script>
                document.getElementById('ssid').addEventListener('change', function() {
                    var manualDiv = document.getElementById('manual-ssid');
                    var manualInput = document.getElementById('manual_ssid_input');

                    if (this.value === 'manual') {
                        manualDiv.style.display = 'block';
                        manualInput.required = true;
                    } else {
                        manualDiv.style.display = 'none';
                        manualInput.required = false;
                    }
                });

                document.getElementById('wifi-form').addEventListener('submit', function(e) {
                    var ssidSelect = document.getElementById('ssid');
                    var manualInput = document.getElementById('manual_ssid_input');
                    var submitButton = document.getElementById('wifi-submit');

                    if (ssidSelect.value === 'manual' && manualInput.value) {
                        // Create a hidden input with the manual SSID
                        var hiddenInput = document.createElement('input');
                        hiddenInput.type = 'hidden';
                        hiddenInput.name = 'ssid';
                        hiddenInput.value = manualInput.value;
                        this.appendChild(hiddenInput);
                        ssidSelect.name = 'ssid_select'; // Change name so it doesn't conflict
                    }

                    // Show loading state
                    submitButton.innerHTML = 'Connecting...<span class="loading"></span>';
                    submitButton.disabled = true;
                });
                </script>

            <?php elseif ($current_step == 'dropbox'): ?>
                <div class="form-section">
                    <h2><span class="icon">☁️</span>Dropbox Configuration</h2>

                    <div class="instructions">
                        <h3>Get your Dropbox Access Token:</h3>
                        <ol>
                            <li>Visit <a href="https://www.dropbox.com/developers/apps" target="_blank">dropbox.com/developers/apps</a></li>
                            <li>Click <strong>"Create app"</strong></li>
                            <li>Choose <strong>"Scoped access"</strong> → <strong>"App folder"</strong></li>
                            <li>Name it <strong>"CameraBridge"</strong> and create the app</li>
                            <li>In the app settings, go to the <strong>"Settings"</strong> tab</li>
                            <li>Scroll down and click <strong>"Generate access token"</strong></li>
                            <li>Copy the token and paste it below</li>
                        </ol>
                        <p><strong>Note:</strong> The app folder access means your photos will be stored in <code>/Apps/CameraBridge/</code> in your Dropbox.</p>
                    </div>

                    <form method="POST" id="dropbox-form">
                        <div class="form-group">
                            <label for="dropbox_token">Dropbox Access Token:</label>
                            <textarea name="dropbox_token" id="dropbox_token" rows="4" required
                                      placeholder="Paste your Dropbox access token here..."></textarea>
                        </div>

                        <button type="submit" name="submit" value="dropbox_token" id="dropbox-submit">
                            Configure Dropbox
                        </button>
                    </form>
                </div>

                <script>
                document.getElementById('dropbox-form').addEventListener('submit', function(e) {
                    var submitButton = document.getElementById('dropbox-submit');
                    submitButton.innerHTML = 'Configuring...<span class="loading"></span>';
                    submitButton.disabled = true;
                });
                </script>

            <?php elseif ($current_step == 'complete'): ?>
                <div class="form-section">
                    <h2><span class="icon">✅</span>Setup Complete!</h2>

                    <div class="status-grid">
                        <div class="status-item <?php echo $wifi_configured ? 'success' : ''; ?>">
                            <h4>WiFi Connection</h4>
                            <p><?php echo $wifi_configured ? '✓ Connected' : '✗ Not configured'; ?></p>
                        </div>
                        <div class="status-item <?php echo $dropbox_configured ? 'success' : ''; ?>">
                            <h4>Dropbox Sync</h4>
                            <p><?php echo $dropbox_configured ? '✓ Connected' : '✗ Not configured'; ?></p>
                        </div>
                    </div>

                    <div class="instructions">
                        <h3>🎉 Your Camera Bridge is Ready!</h3>

                        <h4>What happens next:</h4>
                        <ul class="feature-list">
                            <li>Device will automatically start the camera bridge service</li>
                            <li>SMB share will be available for camera connections</li>
                            <li>Photos will automatically sync to Dropbox folder <code>/Apps/CameraBridge/</code></li>
                            <li>You can monitor status through the web interface</li>
                        </ul>

                        <h4>Camera Setup Instructions:</h4>
                        <ul class="feature-list">
                            <li>Connect your camera via Ethernet cable to this device</li>
                            <li>Configure camera to save to SMB share: <code>\\<?php echo $_SERVER['SERVER_ADDR'] ?? 'device-ip'; ?>\photos</code></li>
                            <li>Use SMB credentials: Username <code>camera</code>, Password <code>camera123</code></li>
                            <li>Set camera to automatically save photos to the network share</li>
                        </ul>

                        <h4>Monitoring & Management:</h4>
                        <ul class="feature-list">
                            <li>Web status page: <a href="status.php">View Status Dashboard</a></li>
                            <li>Connect a display locally and use the terminal interface</li>
                            <li>Check logs for troubleshooting if needed</li>
                        </ul>
                    </div>

                    <form method="POST" id="finish-form">
                        <button type="submit" name="submit" value="finish_setup" id="finish-submit">
                            🚀 Finish Setup & Start Services
                        </button>
                    </form>
                </div>

                <script>
                document.getElementById('finish-form').addEventListener('submit', function(e) {
                    var submitButton = document.getElementById('finish-submit');
                    submitButton.innerHTML = 'Starting Services...<span class="loading"></span>';
                    submitButton.disabled = true;
                });
                </script>

            <?php endif; ?>
        </div>

        <div class="footer">
            <p>Camera Bridge Setup v1.0 | For help, connect a display and use the terminal interface</p>
            <p><a href="status.php">View Status Dashboard</a> | <a href="?step=wifi">WiFi Setup</a> | <a href="?step=dropbox">Dropbox Setup</a></p>
        </div>
    </div>
</body>
</html>