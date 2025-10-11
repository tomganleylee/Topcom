<?php
session_start();

// Auto-detect network interfaces
$wifi_interface = trim(shell_exec("ip link | grep -E '^[0-9]+: w' | cut -d: -f2 | tr -d ' ' | head -1"));
$eth_interface = trim(shell_exec("ip link | grep -E '^[0-9]+: e' | cut -d: -f2 | tr -d ' ' | head -1"));

// Default to common names if not detected
$wifi_interface = $wifi_interface ?: 'wlan0';
$eth_interface = $eth_interface ?: 'eth0';

// Check configurations
$dropbox_configured = file_exists('/home/camerabridge/.config/rclone/rclone.conf') &&
                      strpos(@file_get_contents('/home/camerabridge/.config/rclone/rclone.conf'), '[dropbox]') !== false;

$wifi_configured = trim(shell_exec("iwgetid -r 2>/dev/null")) !== "";

$message = '';
$message_type = '';

// Handle form submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {

    // WiFi Configuration
    if (isset($_POST['wifi_submit'])) {
        $ssid = escapeshellarg($_POST['ssid']);
        $password = escapeshellarg($_POST['password']);

        // Create wpa_supplicant config
        $config = "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n";
        $config .= "update_config=1\n";
        $config .= "country=US\n\n";
        $config .= "network={\n";
        $config .= "    ssid=" . $ssid . "\n";
        $config .= "    psk=" . $password . "\n";
        $config .= "    key_mgmt=WPA-PSK\n";
        $config .= "}\n";

        file_put_contents('/tmp/wpa_supplicant.conf', $config);

        // Apply configuration
        exec('sudo cp /tmp/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf 2>&1', $output, $return_code);

        if ($return_code == 0) {
            exec('sudo systemctl restart wpa_supplicant 2>&1');
            $message = 'WiFi configuration updated successfully!';
            $message_type = 'success';
            $wifi_configured = true;
        } else {
            $message = 'Failed to update WiFi configuration';
            $message_type = 'error';
        }
    }

    // Dropbox Configuration
    if (isset($_POST['dropbox_submit'])) {
        $token = trim($_POST['dropbox_token']);

        if (!empty($token)) {
            // Create rclone configuration
            $config = "[dropbox]\n";
            $config .= "type = dropbox\n";
            $config .= 'token = {"access_token":"' . $token . '","token_type":"bearer","expiry":"0001-01-01T00:00:00Z"}' . "\n";

            // Save to temporary file
            file_put_contents('/tmp/rclone.conf', $config);

            // Create directory and copy config
            exec('sudo mkdir -p /home/camerabridge/.config/rclone 2>&1');
            exec('sudo cp /tmp/rclone.conf /home/camerabridge/.config/rclone/rclone.conf 2>&1', $output, $return_code);
            exec('sudo chown -R camerabridge:camerabridge /home/camerabridge/.config/rclone 2>&1');
            exec('sudo chmod 600 /home/camerabridge/.config/rclone/rclone.conf 2>&1');

            if ($return_code == 0) {
                // Restart service
                exec('sudo systemctl restart camera-bridge 2>&1');
                $message = 'Dropbox configured successfully! Photos will sync to Camera-Photos folder.';
                $message_type = 'success';
                $dropbox_configured = true;
            } else {
                $message = 'Failed to save Dropbox configuration';
                $message_type = 'error';
            }
        } else {
            $message = 'Please enter a valid access token';
            $message_type = 'error';
        }
    }
}

// Get system status
$ip_address = trim(shell_exec("hostname -I | awk '{print $1}'"));
$wifi_ssid = trim(shell_exec("iwgetid -r 2>/dev/null"));
$smb_running = trim(shell_exec("systemctl is-active smbd")) == "active";
$service_running = trim(shell_exec("systemctl is-active camera-bridge")) == "active";

// Scan for WiFi networks
$networks = [];
if (isset($_GET['scan'])) {
    exec("sudo iwlist $wifi_interface scan 2>/dev/null | grep ESSID | cut -d'\"' -f2", $networks);
    $networks = array_unique(array_filter($networks));
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
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
        }
        .card {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 30px;
            margin-bottom: 20px;
        }
        h1 {
            color: #333;
            margin-bottom: 10px;
            font-size: 32px;
        }
        h2 {
            color: #555;
            margin: 20px 0 15px;
            font-size: 24px;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .subtitle {
            color: #666;
            margin-bottom: 30px;
            font-size: 16px;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        .status-item {
            display: flex;
            align-items: center;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 4px solid #ddd;
        }
        .status-item.success {
            background: #d4edda;
            color: #155724;
            border-left-color: #28a745;
        }
        .status-item.warning {
            background: #fff3cd;
            color: #856404;
            border-left-color: #ffc107;
        }
        .status-item.error {
            background: #f8d7da;
            color: #721c24;
            border-left-color: #dc3545;
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
        input[type="text"], input[type="password"], textarea, select {
            width: 100%;
            padding: 12px;
            border: 2px solid #e1e4e8;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s;
        }
        input:focus, textarea:focus, select:focus {
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
        code {
            background: #f6f8fa;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Courier New', monospace;
        }
        .scan-button {
            background: #28a745;
            padding: 8px 20px;
            font-size: 14px;
            margin-left: 10px;
        }
        .network-list {
            max-height: 200px;
            overflow-y: auto;
            border: 1px solid #ddd;
            border-radius: 8px;
            padding: 10px;
            margin-top: 10px;
        }
        .network-item {
            padding: 8px;
            margin: 5px 0;
            background: #f8f9fa;
            border-radius: 5px;
            cursor: pointer;
        }
        .network-item:hover {
            background: #e9ecef;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="card">
            <h1>📷 Camera Bridge Setup</h1>
            <p class="subtitle">Complete Setup & Configuration</p>

            <?php if ($message): ?>
                <div class="alert <?php echo $message_type; ?>">
                    <?php echo htmlspecialchars($message); ?>
                </div>
            <?php endif; ?>

            <!-- Status Overview -->
            <div class="status-grid">
                <div class="status-item <?php echo $wifi_configured ? 'success' : 'warning'; ?>">
                    <span class="status-icon"><?php echo $wifi_configured ? '✅' : '⚠️'; ?></span>
                    <div>
                        <strong>WiFi</strong><br>
                        <?php echo $wifi_configured ? "Connected: $wifi_ssid" : 'Not configured'; ?>
                    </div>
                </div>

                <div class="status-item <?php echo $dropbox_configured ? 'success' : 'warning'; ?>">
                    <span class="status-icon"><?php echo $dropbox_configured ? '✅' : '⚠️'; ?></span>
                    <div>
                        <strong>Dropbox</strong><br>
                        <?php echo $dropbox_configured ? 'Configured' : 'Not configured'; ?>
                    </div>
                </div>

                <div class="status-item <?php echo $smb_running ? 'success' : 'error'; ?>">
                    <span class="status-icon"><?php echo $smb_running ? '✅' : '❌'; ?></span>
                    <div>
                        <strong>File Sharing</strong><br>
                        <?php echo $smb_running ? 'Running' : 'Not running'; ?>
                    </div>
                </div>

                <div class="status-item <?php echo $service_running ? 'success' : 'warning'; ?>">
                    <span class="status-icon"><?php echo $service_running ? '✅' : '⚠️'; ?></span>
                    <div>
                        <strong>Sync Service</strong><br>
                        <?php echo $service_running ? 'Running' : 'Stopped'; ?>
                    </div>
                </div>
            </div>
        </div>

        <!-- WiFi Configuration -->
        <div class="card">
            <h2>📡 WiFi Configuration</h2>
            <p>Interface: <code><?php echo $wifi_interface; ?></code> |
               Status: <?php echo $wifi_configured ? "Connected to <strong>$wifi_ssid</strong>" : "Not connected"; ?></p>

            <form method="post">
                <div class="form-group">
                    <label for="ssid">Network Name (SSID)</label>
                    <div style="display: flex;">
                        <select name="ssid" id="ssid" onchange="if(this.value=='manual') document.getElementById('manual_ssid').style.display='block';">
                            <option value="">Select a network...</option>
                            <?php if ($wifi_ssid): ?>
                                <option value="<?php echo htmlspecialchars($wifi_ssid); ?>" selected>
                                    Current: <?php echo htmlspecialchars($wifi_ssid); ?>
                                </option>
                            <?php endif; ?>
                            <option value="manual">Enter manually...</option>
                        </select>
                        <a href="?scan=1" class="button scan-button" style="text-decoration: none;">Scan</a>
                    </div>
                    <input type="text" id="manual_ssid" name="ssid" placeholder="Enter network name"
                           style="display:none; margin-top:10px;">
                </div>

                <?php if (!empty($networks)): ?>
                    <div class="network-list">
                        <strong>Available Networks:</strong><br>
                        <?php foreach ($networks as $network): ?>
                            <div class="network-item" onclick="selectNetwork('<?php echo htmlspecialchars($network); ?>')">
                                📶 <?php echo htmlspecialchars($network); ?>
                            </div>
                        <?php endforeach; ?>
                    </div>
                <?php endif; ?>

                <div class="form-group">
                    <label for="password">WiFi Password</label>
                    <input type="password" name="password" id="password" placeholder="Enter WiFi password">
                </div>

                <button type="submit" name="wifi_submit">Connect to WiFi</button>
            </form>
        </div>

        <!-- Dropbox Configuration -->
        <div class="card">
            <h2>☁️ Dropbox Configuration</h2>
            <?php if (!$dropbox_configured): ?>
                <form method="post">
                    <div class="form-group">
                        <label for="dropbox_token">Dropbox Access Token</label>
                        <textarea name="dropbox_token" id="dropbox_token" rows="4"
                            placeholder="Paste your Dropbox access token here" required></textarea>
                        <small style="color: #666;">
                            Get your token from the
                            <a href="https://www.dropbox.com/developers/apps" target="_blank">Dropbox App Console</a>
                        </small>
                    </div>
                    <button type="submit" name="dropbox_submit">Configure Dropbox</button>
                </form>
            <?php else: ?>
                <div class="alert success">
                    ✅ Dropbox is configured and ready to sync photos!
                </div>
                <form method="post" style="margin-top: 15px;">
                    <input type="hidden" name="dropbox_token" value="">
                    <button type="submit" name="dropbox_submit"
                            onclick="return confirm('This will remove the current Dropbox configuration. Continue?')">
                        Reconfigure Dropbox
                    </button>
                </form>
            <?php endif; ?>
        </div>

        <!-- Network Share Info -->
        <div class="card">
            <div class="info-box">
                <h3>📁 Network Share Access</h3>
                <p>
                    Connect your device to the ethernet port and access the share at:<br><br>
                    <strong>Windows:</strong> <code>\\192.168.10.1\photos</code><br>
                    <strong>Mac/Linux:</strong> <code>smb://192.168.10.1/photos</code><br><br>
                    <strong>Credentials:</strong><br>
                    Username: <code>camera</code><br>
                    Password: <code>camera123</code>
                </p>
            </div>

            <?php if ($dropbox_configured && $service_running): ?>
                <div class="info-box" style="margin-top: 15px;">
                    <h3>✨ System Ready!</h3>
                    <p>
                        Your Camera Bridge is fully configured. Photos dropped into the network share
                        will automatically sync to your Dropbox <code>Camera-Photos</code> folder.
                    </p>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <script>
        function selectNetwork(ssid) {
            document.getElementById('ssid').value = 'manual';
            document.getElementById('manual_ssid').style.display = 'block';
            document.getElementById('manual_ssid').value = ssid;
        }
    </script>
</body>
</html>