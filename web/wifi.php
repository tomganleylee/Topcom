<?php
session_start();

$message = '';
$wifi_manager = '/opt/camera-bridge/scripts/wifi-manager.sh';

// Get current WiFi status
function get_current_wifi_status() {
    exec('iwgetid -r 2>/dev/null', $output);
    return !empty($output) ? $output[0] : null;
}

function get_wifi_ip() {
    exec("hostname -I | awk '{print $1}'", $output);
    return !empty($output) ? $output[0] : 'No IP';
}

function get_saved_networks() {
    global $wifi_manager;
    exec("sudo $wifi_manager list-saved 2>/dev/null", $output);
    return $output;
}

function scan_available_networks() {
    global $wifi_manager;
    exec("sudo $wifi_manager scan 2>/dev/null", $output);
    return array_filter($output, function($network) {
        return !empty(trim($network));
    });
}

// Handle form submissions
if (isset($_POST['action'])) {
    switch ($_POST['action']) {
        case 'connect_new':
            $ssid = trim($_POST['ssid']);
            $password = trim($_POST['password']);

            if (!empty($ssid)) {
                $command = escapeshellcmd("sudo $wifi_manager connect " . escapeshellarg($ssid) . " " . escapeshellarg($password));
                exec($command . " 2>&1", $output, $return_code);

                if ($return_code == 0) {
                    $message = '<div class="success">✅ Successfully connected to ' . htmlspecialchars($ssid) . ' and saved for future use!</div>';
                } else {
                    $message = '<div class="error">❌ Failed to connect to ' . htmlspecialchars($ssid) . '. Please check your credentials.</div>';
                }
            }
            break;

        case 'connect_saved':
            $ssid = trim($_POST['saved_ssid']);

            if (!empty($ssid)) {
                $command = escapeshellcmd("sudo $wifi_manager connect-saved " . escapeshellarg($ssid));
                exec($command . " 2>&1", $output, $return_code);

                if ($return_code == 0) {
                    $message = '<div class="success">✅ Successfully connected to saved network: ' . htmlspecialchars($ssid) . '</div>';
                } else {
                    $message = '<div class="error">❌ Failed to connect to saved network: ' . htmlspecialchars($ssid) . '</div>';
                }
            }
            break;

        case 'remove_saved':
            $ssid = trim($_POST['remove_ssid']);

            if (!empty($ssid)) {
                $command = escapeshellcmd("sudo $wifi_manager remove-saved " . escapeshellarg($ssid));
                exec($command . " 2>&1", $output, $return_code);

                if ($return_code == 0) {
                    $message = '<div class="success">✅ Removed saved network: ' . htmlspecialchars($ssid) . '</div>';
                } else {
                    $message = '<div class="error">❌ Failed to remove network: ' . htmlspecialchars($ssid) . '</div>';
                }
            }
            break;

        case 'auto_connect':
            $command = escapeshellcmd("sudo $wifi_manager auto-connect");
            exec($command . " 2>&1", $output, $return_code);

            if ($return_code == 0) {
                $message = '<div class="success">✅ Auto-connect attempted. Check current status below.</div>';
            } else {
                $message = '<div class="warning">⚠️ Auto-connect completed but no suitable networks found.</div>';
            }
            break;
    }
}

$current_ssid = get_current_wifi_status();
$current_ip = get_wifi_ip();
$saved_networks = get_saved_networks();
$available_networks = scan_available_networks();
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WiFi Management - Camera Bridge</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        .header {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 30px;
            margin-bottom: 20px;
            text-align: center;
        }
        .header h1 {
            color: #333;
            margin-bottom: 10px;
        }
        .grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 20px;
        }
        .card {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 30px;
        }
        .card h2 {
            color: #333;
            margin-bottom: 20px;
            padding-bottom: 10px;
            border-bottom: 2px solid #f0f0f0;
        }
        .status-info {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .status-connected {
            background: #d4edda;
            color: #155724;
        }
        .status-disconnected {
            background: #f8d7da;
            color: #721c24;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 500;
            color: #333;
        }
        input, select, button {
            width: 100%;
            padding: 12px 15px;
            border: 2px solid #e0e0e0;
            border-radius: 10px;
            font-size: 1em;
            transition: border-color 0.3s;
        }
        input:focus, select:focus {
            outline: none;
            border-color: #667eea;
        }
        button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            cursor: pointer;
            font-weight: 500;
            transition: transform 0.3s;
        }
        button:hover {
            transform: translateY(-2px);
        }
        .button-secondary {
            background: #6c757d;
        }
        .button-danger {
            background: #dc3545;
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
        .network-list {
            list-style: none;
        }
        .network-item {
            background: #f8f9fa;
            padding: 15px;
            margin-bottom: 10px;
            border-radius: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .network-item.available {
            background: #e7f3ff;
            border-left: 4px solid #2196f3;
        }
        .network-info {
            flex-grow: 1;
        }
        .network-actions {
            display: flex;
            gap: 10px;
        }
        .network-actions button {
            width: auto;
            padding: 8px 15px;
            font-size: 0.9em;
        }
        .nav-buttons {
            text-align: center;
            margin-top: 20px;
        }
        .nav-buttons a {
            display: inline-block;
            padding: 12px 30px;
            background: white;
            color: #333;
            text-decoration: none;
            border-radius: 10px;
            margin: 0 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }
        .nav-buttons a:hover {
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📶 WiFi Management</h1>
            <p>Manage your wireless network connections with automatic password saving</p>
        </div>

        <?php if ($message): ?>
            <?php echo $message; ?>
        <?php endif; ?>

        <div class="grid">
            <!-- Current Status -->
            <div class="card">
                <h2>📊 Current Status</h2>
                <div class="status-info <?php echo $current_ssid ? 'status-connected' : 'status-disconnected'; ?>">
                    <?php if ($current_ssid): ?>
                        <strong>✅ Connected to:</strong> <?php echo htmlspecialchars($current_ssid); ?><br>
                        <strong>IP Address:</strong> <?php echo htmlspecialchars($current_ip); ?>
                    <?php else: ?>
                        <strong>❌ Not Connected</strong><br>
                        No active WiFi connection
                    <?php endif; ?>
                </div>

                <form method="POST">
                    <input type="hidden" name="action" value="auto_connect">
                    <button type="submit" class="button-secondary">🔄 Try Auto-Connect</button>
                </form>
            </div>

            <!-- Connect to New Network -->
            <div class="card">
                <h2>🔗 Connect to New Network</h2>
                <form method="POST">
                    <input type="hidden" name="action" value="connect_new">

                    <div class="form-group">
                        <label for="ssid">Select Network:</label>
                        <select name="ssid" id="ssid" required>
                            <option value="">Choose a network...</option>
                            <?php foreach ($available_networks as $network): ?>
                                <option value="<?php echo htmlspecialchars($network); ?>">
                                    <?php echo htmlspecialchars($network); ?>
                                </option>
                            <?php endforeach; ?>
                        </select>
                    </div>

                    <div class="form-group">
                        <label for="password">Password:</label>
                        <input type="password" name="password" id="password" placeholder="Enter network password (leave blank for open networks)">
                    </div>

                    <button type="submit">Connect & Save Network</button>
                </form>

                <div style="margin-top: 15px; font-size: 0.9em; color: #666;">
                    💡 <strong>Tip:</strong> Successfully connected networks are automatically saved for future use!
                </div>
            </div>

            <!-- Saved Networks -->
            <div class="card">
                <h2>💾 Saved Networks (<?php echo count(array_filter($saved_networks, function($line) { return strpos($line, '. ') !== false; })); ?>)</h2>

                <?php if (empty($saved_networks) || in_array('No saved networks', $saved_networks)): ?>
                    <div class="status-info">
                        <strong>No saved networks yet</strong><br>
                        Connect to a network above to automatically save it for future use.
                    </div>
                <?php else: ?>
                    <ul class="network-list">
                        <?php
                        foreach ($saved_networks as $line) {
                            if (strpos($line, '. ') !== false) {
                                // Parse network line: "1. ✓ NetworkName (Priority: 10) 🔄"
                                preg_match('/^\d+\.\s+[✓○]\s+(.+?)\s+\(Priority/', $line, $matches);
                                if (isset($matches[1])) {
                                    $network_name = trim($matches[1]);
                                    $is_available = in_array($network_name, $available_networks);
                                    $has_password = strpos($line, '✓') !== false;
                        ?>
                            <li class="network-item <?php echo $is_available ? 'available' : ''; ?>">
                                <div class="network-info">
                                    <strong><?php echo htmlspecialchars($network_name); ?></strong>
                                    <?php echo $has_password ? '🔒' : '🔓'; ?>
                                    <?php echo $is_available ? '⚡ Available' : '📍 Not in range'; ?>
                                </div>
                                <div class="network-actions">
                                    <?php if ($is_available): ?>
                                        <form method="POST" style="display: inline;">
                                            <input type="hidden" name="action" value="connect_saved">
                                            <input type="hidden" name="saved_ssid" value="<?php echo htmlspecialchars($network_name); ?>">
                                            <button type="submit" class="button-secondary">Connect</button>
                                        </form>
                                    <?php endif; ?>
                                    <form method="POST" style="display: inline;">
                                        <input type="hidden" name="action" value="remove_saved">
                                        <input type="hidden" name="remove_ssid" value="<?php echo htmlspecialchars($network_name); ?>">
                                        <button type="submit" class="button-danger" onclick="return confirm('Remove saved network: <?php echo htmlspecialchars($network_name); ?>?')">Remove</button>
                                    </form>
                                </div>
                            </li>
                        <?php
                                }
                            }
                        }
                        ?>
                    </ul>
                <?php endif; ?>
            </div>

            <!-- Available Networks -->
            <div class="card">
                <h2>📡 Available Networks</h2>
                <?php if (empty($available_networks)): ?>
                    <div class="status-info">
                        <strong>No networks found</strong><br>
                        <button onclick="location.reload()" style="margin-top: 10px;">🔄 Refresh Scan</button>
                    </div>
                <?php else: ?>
                    <div style="margin-bottom: 15px; font-size: 0.9em; color: #666;">
                        Found <?php echo count($available_networks); ?> networks in range
                    </div>
                    <ul class="network-list">
                        <?php foreach ($available_networks as $network): ?>
                            <li class="network-item">
                                <div class="network-info">
                                    <strong><?php echo htmlspecialchars($network); ?></strong>
                                    📶 In range
                                </div>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                    <button onclick="location.reload()" class="button-secondary">🔄 Refresh Scan</button>
                <?php endif; ?>
            </div>
        </div>

        <div class="nav-buttons">
            <a href="index.php">🏠 Back to Setup</a>
            <a href="status.php">📊 System Status</a>
        </div>
    </div>

    <script>
        // Auto-refresh every 30 seconds to keep network status current
        setTimeout(function() {
            location.reload();
        }, 30000);
    </script>
</body>
</html>