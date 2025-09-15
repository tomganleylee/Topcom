<?php
// Get system status functions
function get_wifi_status() {
    exec('iwgetid -r 2>/dev/null', $output);
    return !empty($output) ? $output[0] : 'Not connected';
}

function get_ip_address() {
    exec("hostname -I | awk '{print $1}'", $output);
    return !empty($output) ? $output[0] : 'No IP';
}

function check_service_status($service) {
    exec("systemctl is-active $service 2>/dev/null", $output);
    return !empty($output) && $output[0] == 'active';
}

function check_dropbox_connection() {
    exec('sudo -u camerabridge rclone lsd dropbox: 2>/dev/null', $output, $return_code);
    return $return_code == 0;
}

function get_recent_files($hours = 24) {
    exec("find /srv/samba/camera-share -type f -mtime -1 2>/dev/null | wc -l", $output);
    return !empty($output) ? intval($output[0]) : 0;
}

function get_disk_usage() {
    exec("df -h / | awk 'NR==2{printf \"%s\", \$5}'", $output);
    return !empty($output) ? $output[0] : 'Unknown';
}

function get_memory_usage() {
    exec("free | grep Mem | awk '{printf(\"%.1f%%\", \$3/\$2 * 100.0)}'", $output);
    return !empty($output) ? $output[0] : 'Unknown';
}

function get_cpu_temperature() {
    // Try multiple methods to get CPU temperature
    $temp_sources = [
        '/sys/class/thermal/thermal_zone0/temp',
        '/sys/class/hwmon/hwmon0/temp1_input',
        '/sys/class/hwmon/hwmon1/temp1_input'
    ];

    foreach ($temp_sources as $source) {
        if (file_exists($source)) {
            $temp = file_get_contents($source);
            $temp = intval($temp) / 1000; // Convert from millicelsius
            if ($temp > 0 && $temp < 150) { // Reasonable temperature range
                return round($temp, 1) . '°C';
            }
        }
    }

    // Fallback: try sensors command
    exec('sensors 2>/dev/null | grep -E "Core|CPU" | head -1 | grep -o "[0-9]*\.[0-9]*°C" | head -1', $output);
    return !empty($output) ? $output[0] : 'N/A';
}

function get_uptime() {
    exec("uptime -p", $output);
    return !empty($output) ? $output[0] : 'Unknown';
}

function get_storage_info() {
    $info = [];
    exec("df -h /srv/samba/camera-share 2>/dev/null | awk 'NR==2{print \$2\" total, \"\$3\" used, \"\$4\" available\"}'", $output);
    $info['camera_share'] = !empty($output) ? $output[0] : 'Unknown';

    exec("du -sh /srv/samba/camera-share 2>/dev/null | awk '{print \$1}'", $output);
    $info['photos_size'] = !empty($output) ? $output[0] : '0B';

    return $info;
}

function get_network_info() {
    $info = [];
    $info['wifi_ssid'] = get_wifi_status();
    $info['ip_address'] = get_ip_address();

    exec("iwconfig wlan0 2>/dev/null | grep 'Signal level' | awk '{print \$4}' | cut -d'=' -f2", $output);
    $info['signal_strength'] = !empty($output) ? $output[0] : 'Unknown';

    return $info;
}

function get_sync_stats() {
    $stats = [];
    $log_file = '/var/log/camera-bridge/service.log';

    if (file_exists($log_file)) {
        // Count successful syncs in the last 24 hours
        exec("grep 'Successfully synced' $log_file | grep '$(date '+%Y-%m-%d')' | wc -l", $output);
        $stats['synced_today'] = !empty($output) ? intval($output[0]) : 0;

        // Count failed syncs in the last 24 hours
        exec("grep 'Failed to sync' $log_file | grep '$(date '+%Y-%m-%d')' | wc -l", $output);
        $stats['failed_today'] = !empty($output) ? intval($output[0]) : 0;

        // Get last sync time
        exec("grep 'Successfully synced' $log_file | tail -1 | awk '{print \$1\" \"\$2}'", $output);
        $stats['last_sync'] = !empty($output) ? $output[0] : 'Never';
    } else {
        $stats = ['synced_today' => 0, 'failed_today' => 0, 'last_sync' => 'Never'];
    }

    return $stats;
}

// Collect all system information
$wifi_ssid = get_wifi_status();
$network_info = get_network_info();
$ip_address = $network_info['ip_address'];

$bridge_running = check_service_status('camera-bridge') || (file_exists('/var/run/camera-bridge.pid') && posix_kill(file_get_contents('/var/run/camera-bridge.pid'), 0));
$smb_running = check_service_status('smbd');
$nginx_running = check_service_status('nginx');
$dropbox_connected = check_dropbox_connection();

$recent_files = get_recent_files();
$disk_usage = get_disk_usage();
$memory_usage = get_memory_usage();
$cpu_temp = get_cpu_temperature();
$uptime = get_uptime();
$storage_info = get_storage_info();
$sync_stats = get_sync_stats();

// Calculate overall health score
$health_score = 100;
if ($wifi_ssid == 'Not connected') $health_score -= 30;
if (!$bridge_running) $health_score -= 25;
if (!$smb_running) $health_score -= 20;
if (!$dropbox_connected) $health_score -= 15;
if (intval($disk_usage) > 90) $health_score -= 10;

$health_status = $health_score >= 80 ? 'excellent' : ($health_score >= 60 ? 'good' : ($health_score >= 40 ? 'warning' : 'critical'));
?>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Camera Bridge Status</title>
    <meta http-equiv="refresh" content="30">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background: #0a0e27;
            color: #ffffff;
            min-height: 100vh;
            padding: 20px;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
        }

        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 30px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
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

        .health-indicator {
            display: inline-block;
            padding: 8px 20px;
            border-radius: 20px;
            font-weight: 600;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-top: 15px;
        }

        .health-excellent { background: #28a745; }
        .health-good { background: #ffc107; color: #000; }
        .health-warning { background: #fd7e14; }
        .health-critical { background: #dc3545; }

        .dashboard {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }

        .card {
            background: linear-gradient(145deg, #1e2139, #252847);
            border-radius: 15px;
            padding: 25px;
            box-shadow: 0 8px 25px rgba(0,0,0,0.3);
            border: 1px solid #3a3f5c;
            transition: all 0.3s ease;
        }

        .card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 35px rgba(0,0,0,0.4);
        }

        .card-header {
            display: flex;
            align-items: center;
            margin-bottom: 20px;
        }

        .card-icon {
            font-size: 1.8rem;
            margin-right: 15px;
            opacity: 0.8;
        }

        .card-title {
            font-size: 1.1rem;
            font-weight: 600;
            color: #e0e6ed;
        }

        .card-value {
            font-size: 2rem;
            font-weight: 300;
            margin-bottom: 10px;
        }

        .card-subtitle {
            font-size: 0.9rem;
            color: #8892b0;
            line-height: 1.4;
        }

        .status-online { color: #4ade80; }
        .status-offline { color: #ef4444; }
        .status-warning { color: #f59e0b; }

        .card.success {
            border-left: 4px solid #4ade80;
        }

        .card.error {
            border-left: 4px solid #ef4444;
        }

        .card.warning {
            border-left: 4px solid #f59e0b;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 20px;
        }

        .stat-item {
            background: rgba(255,255,255,0.05);
            padding: 15px;
            border-radius: 10px;
            text-align: center;
        }

        .stat-value {
            font-size: 1.5rem;
            font-weight: 600;
            color: #4ade80;
        }

        .stat-label {
            font-size: 0.8rem;
            color: #8892b0;
            text-transform: uppercase;
            letter-spacing: 1px;
        }

        .info-section {
            background: linear-gradient(145deg, #1e2139, #252847);
            border-radius: 15px;
            padding: 30px;
            margin-top: 30px;
            border: 1px solid #3a3f5c;
        }

        .info-section h3 {
            color: #e0e6ed;
            margin-bottom: 20px;
            font-size: 1.3rem;
        }

        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }

        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 12px 0;
            border-bottom: 1px solid #3a3f5c;
        }

        .info-item:last-child {
            border-bottom: none;
        }

        .info-label {
            font-weight: 600;
            color: #8892b0;
        }

        .info-value {
            color: #e0e6ed;
            font-family: monospace;
        }

        .progress-bar {
            width: 100%;
            height: 8px;
            background: rgba(255,255,255,0.1);
            border-radius: 4px;
            overflow: hidden;
            margin: 10px 0;
        }

        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4ade80, #22c55e);
            transition: width 0.3s ease;
        }

        .progress-fill.warning {
            background: linear-gradient(90deg, #f59e0b, #d97706);
        }

        .progress-fill.danger {
            background: linear-gradient(90deg, #ef4444, #dc2626);
        }

        .refresh-info {
            text-align: center;
            color: #6b7280;
            margin-top: 40px;
            padding: 20px;
            background: rgba(255,255,255,0.03);
            border-radius: 10px;
        }

        .action-buttons {
            display: flex;
            gap: 15px;
            flex-wrap: wrap;
            justify-content: center;
            margin-top: 20px;
        }

        .btn {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            text-decoration: none;
            font-weight: 600;
            transition: all 0.3s ease;
            cursor: pointer;
        }

        .btn-primary {
            background: linear-gradient(135deg, #007bff, #0056b3);
            color: white;
        }

        .btn-success {
            background: linear-gradient(135deg, #28a745, #1e7e34);
            color: white;
        }

        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.3);
        }

        @media (max-width: 768px) {
            .dashboard {
                grid-template-columns: 1fr;
            }
            .header h1 {
                font-size: 2rem;
            }
            .info-grid {
                grid-template-columns: 1fr;
            }
            .action-buttons {
                flex-direction: column;
            }
        }

        .pulse {
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📷 Camera Bridge Status</h1>
            <p class="subtitle">Real-time monitoring dashboard</p>
            <div class="health-indicator health-<?php echo $health_status; ?>">
                System Health: <?php echo ucfirst($health_status); ?> (<?php echo $health_score; ?>%)
            </div>
        </div>

        <div class="dashboard">
            <!-- WiFi Status Card -->
            <div class="card <?php echo $wifi_ssid != 'Not connected' ? 'success' : 'error'; ?>">
                <div class="card-header">
                    <div class="card-icon">📶</div>
                    <div class="card-title">WiFi Connection</div>
                </div>
                <div class="card-value <?php echo $wifi_ssid != 'Not connected' ? 'status-online' : 'status-offline'; ?>">
                    <?php echo $wifi_ssid; ?>
                </div>
                <div class="card-subtitle">
                    IP: <?php echo $ip_address; ?><br>
                    Signal: <?php echo $network_info['signal_strength']; ?>
                </div>
            </div>

            <!-- Bridge Service Card -->
            <div class="card <?php echo $bridge_running ? 'success' : 'error'; ?>">
                <div class="card-header">
                    <div class="card-icon">🔄</div>
                    <div class="card-title">Bridge Service</div>
                </div>
                <div class="card-value <?php echo $bridge_running ? 'status-online' : 'status-offline'; ?>">
                    <?php echo $bridge_running ? 'Running' : 'Stopped'; ?>
                    <?php if ($bridge_running): ?>
                        <span class="pulse">●</span>
                    <?php endif; ?>
                </div>
                <div class="card-subtitle">
                    Monitoring photos and syncing to cloud
                </div>
            </div>

            <!-- SMB Server Card -->
            <div class="card <?php echo $smb_running ? 'success' : 'error'; ?>">
                <div class="card-header">
                    <div class="card-icon">📁</div>
                    <div class="card-title">SMB Server</div>
                </div>
                <div class="card-value <?php echo $smb_running ? 'status-online' : 'status-offline'; ?>">
                    <?php echo $smb_running ? 'Active' : 'Inactive'; ?>
                </div>
                <div class="card-subtitle">
                    Share: \\<?php echo $ip_address; ?>\photos
                </div>
            </div>

            <!-- Dropbox Sync Card -->
            <div class="card <?php echo $dropbox_connected ? 'success' : 'error'; ?>">
                <div class="card-header">
                    <div class="card-icon">☁️</div>
                    <div class="card-title">Dropbox Sync</div>
                </div>
                <div class="card-value <?php echo $dropbox_connected ? 'status-online' : 'status-offline'; ?>">
                    <?php echo $dropbox_connected ? 'Connected' : 'Disconnected'; ?>
                </div>
                <div class="card-subtitle">
                    <?php if ($dropbox_connected): ?>
                        Synced today: <?php echo $sync_stats['synced_today']; ?> files<br>
                        Failed: <?php echo $sync_stats['failed_today']; ?> files
                    <?php else: ?>
                        Check configuration
                    <?php endif; ?>
                </div>
            </div>

            <!-- Recent Activity Card -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">📸</div>
                    <div class="card-title">Recent Photos</div>
                </div>
                <div class="card-value status-online">
                    <?php echo $recent_files; ?>
                </div>
                <div class="card-subtitle">
                    New files in last 24 hours<br>
                    Storage: <?php echo $storage_info['photos_size']; ?> used
                </div>
            </div>

            <!-- System Resources Card -->
            <div class="card">
                <div class="card-header">
                    <div class="card-icon">⚡</div>
                    <div class="card-title">System Resources</div>
                </div>
                <div class="stats-grid">
                    <div class="stat-item">
                        <div class="stat-value"><?php echo str_replace('%', '', $disk_usage); ?>%</div>
                        <div class="stat-label">Disk Usage</div>
                        <div class="progress-bar">
                            <div class="progress-fill <?php echo intval($disk_usage) > 80 ? 'danger' : (intval($disk_usage) > 60 ? 'warning' : ''); ?>"
                                 style="width: <?php echo $disk_usage; ?>"></div>
                        </div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value"><?php echo str_replace('%', '', $memory_usage); ?>%</div>
                        <div class="stat-label">Memory</div>
                        <div class="progress-bar">
                            <div class="progress-fill" style="width: <?php echo $memory_usage; ?>"></div>
                        </div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value"><?php echo $cpu_temp; ?></div>
                        <div class="stat-label">CPU Temp</div>
                    </div>
                </div>
            </div>
        </div>

        <div class="info-section">
            <h3>📋 System Information</h3>
            <div class="info-grid">
                <div>
                    <div class="info-item">
                        <span class="info-label">SMB Share Path:</span>
                        <span class="info-value">\\<?php echo $ip_address; ?>\photos</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">SMB Credentials:</span>
                        <span class="info-value">camera / camera123</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Dropbox Folder:</span>
                        <span class="info-value">/Apps/CameraBridge/</span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Last Sync:</span>
                        <span class="info-value"><?php echo $sync_stats['last_sync']; ?></span>
                    </div>
                </div>
                <div>
                    <div class="info-item">
                        <span class="info-label">System Uptime:</span>
                        <span class="info-value"><?php echo $uptime; ?></span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Storage Available:</span>
                        <span class="info-value"><?php echo $storage_info['camera_share']; ?></span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Web Interface:</span>
                        <span class="info-value">http://<?php echo $ip_address; ?></span>
                    </div>
                    <div class="info-item">
                        <span class="info-label">Current Time:</span>
                        <span class="info-value"><?php echo date('Y-m-d H:i:s T'); ?></span>
                    </div>
                </div>
            </div>

            <div class="action-buttons">
                <a href="index.php" class="btn btn-primary">🔧 Setup</a>
                <a href="?refresh=1" class="btn btn-success">🔄 Refresh</a>
                <a href="index.php?step=wifi" class="btn btn-primary">📶 WiFi Setup</a>
                <a href="index.php?step=dropbox" class="btn btn-primary">☁️ Dropbox Setup</a>
            </div>
        </div>

        <div class="refresh-info">
            <p><strong>Auto-refresh:</strong> This page refreshes automatically every 30 seconds</p>
            <p><strong>Terminal Interface:</strong> Connect a display locally and run <code>camera-bridge-ui</code> for advanced management</p>
            <p><strong>Last updated:</strong> <?php echo date('H:i:s'); ?></p>
        </div>
    </div>

    <script>
        // Add some dynamic behavior
        document.addEventListener('DOMContentLoaded', function() {
            // Animate cards on page load
            const cards = document.querySelectorAll('.card');
            cards.forEach((card, index) => {
                card.style.opacity = '0';
                card.style.transform = 'translateY(20px)';
                setTimeout(() => {
                    card.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
                    card.style.opacity = '1';
                    card.style.transform = 'translateY(0)';
                }, index * 100);
            });

            // Show notification if system health is not excellent
            <?php if ($health_status !== 'excellent'): ?>
            setTimeout(() => {
                if (confirm('System health is <?php echo $health_status; ?>. Would you like to view the setup page to resolve issues?')) {
                    window.location.href = 'index.php';
                }
            }, 2000);
            <?php endif; ?>
        });
    </script>
</body>
</html>