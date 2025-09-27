<?php
session_start();

// Set token file path
$token_file = '/tmp/camera-bridge-token-entry.txt';
$status_file = '/tmp/camera-bridge-token-status.txt';

// Handle token submission
if ($_POST['token'] ?? false) {
    $token = trim($_POST['token']);

    // Basic validation
    if (strlen($token) < 40) {
        $error = "Token appears too short. Dropbox tokens should be at least 40 characters.";
    } elseif (preg_match('/\s/', $token)) {
        $error = "Token contains spaces or newlines. Please ensure you copy only the token string.";
    } else {
        // Save token to file
        file_put_contents($token_file, $token);
        file_put_contents($status_file, "success");
        $success = "Token saved successfully! You can now continue in the terminal.";
    }
}

// Check if token was requested (coming from QR scan)
$from_qr = $_GET['qr'] ?? false;
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Camera Bridge - Dropbox Token Entry</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
            color: #333;
        }

        .container {
            max-width: 600px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.2);
            overflow: hidden;
        }

        .header {
            background: #4a5568;
            color: white;
            padding: 20px;
            text-align: center;
        }

        .content {
            padding: 30px;
        }

        .network-info {
            background: #e6fffa;
            border: 1px solid #38b2ac;
            border-radius: 5px;
            padding: 15px;
            margin-bottom: 25px;
        }

        .network-info h3 {
            color: #2c7a7b;
            margin-bottom: 10px;
        }

        .network-info p {
            color: #2d3748;
            font-size: 14px;
        }

        .form-group {
            margin-bottom: 20px;
        }

        label {
            display: block;
            margin-bottom: 8px;
            font-weight: 600;
            color: #2d3748;
        }

        textarea {
            width: 100%;
            min-height: 120px;
            padding: 12px;
            border: 2px solid #e2e8f0;
            border-radius: 5px;
            font-family: monospace;
            font-size: 12px;
            resize: vertical;
        }

        textarea:focus {
            outline: none;
            border-color: #667eea;
        }

        .btn {
            background: #667eea;
            color: white;
            padding: 12px 30px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            width: 100%;
        }

        .btn:hover {
            background: #5a6fd8;
        }

        .success {
            background: #f0fff4;
            border: 1px solid #68d391;
            color: #2f855a;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }

        .error {
            background: #fed7d7;
            border: 1px solid #fc8181;
            color: #c53030;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }

        .instructions {
            background: #f7fafc;
            border-radius: 5px;
            padding: 20px;
            margin-top: 20px;
        }

        .instructions h3 {
            color: #2d3748;
            margin-bottom: 10px;
        }

        .instructions ol {
            padding-left: 20px;
            color: #4a5568;
        }

        .instructions li {
            margin-bottom: 8px;
        }

        .char-count {
            font-size: 12px;
            color: #718096;
            text-align: right;
            margin-top: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📷 Camera Bridge</h1>
            <p>Dropbox Token Entry</p>
        </div>

        <div class="content">
            <?php if ($from_qr): ?>
            <div class="network-info">
                <h3>📱 QR Code Scanned Successfully!</h3>
                <p><strong>Important:</strong> Make sure your device is connected to the same WiFi network as the Camera Bridge system to submit the token.</p>
            </div>
            <?php endif; ?>

            <?php if (isset($success)): ?>
            <div class="success">
                ✅ <?= htmlspecialchars($success) ?>
            </div>
            <?php endif; ?>

            <?php if (isset($error)): ?>
            <div class="error">
                ❌ <?= htmlspecialchars($error) ?>
            </div>
            <?php endif; ?>

            <form method="POST">
                <div class="form-group">
                    <label for="token">Dropbox Access Token</label>
                    <textarea
                        id="token"
                        name="token"
                        placeholder="Paste your Dropbox access token here... (starts with 'sl.' for scoped tokens)"
                        required
                        oninput="updateCharCount()"
                    ><?= htmlspecialchars($_POST['token'] ?? '') ?></textarea>
                    <div class="char-count" id="charCount">0 characters</div>
                </div>

                <button type="submit" class="btn">Save Token</button>
            </form>

            <div class="instructions">
                <h3>📋 How to Get Your Dropbox Token:</h3>
                <ol>
                    <li>Open <strong>https://dropbox.com/developers/apps</strong> in your browser</li>
                    <li>Click <strong>"Create app"</strong></li>
                    <li>Choose <strong>"Scoped access"</strong></li>
                    <li>Choose <strong>"App folder"</strong> (recommended) or <strong>"Full Dropbox"</strong></li>
                    <li>Name your app (e.g., "CameraBridge")</li>
                    <li>Click <strong>"Create app"</strong></li>
                    <li>Go to <strong>"Permissions"</strong> tab</li>
                    <li>Enable: <strong>files.metadata.read</strong>, <strong>files.content.read</strong>, <strong>files.content.write</strong></li>
                    <li>Go to <strong>"Settings"</strong> tab</li>
                    <li>Click <strong>"Generate access token"</strong></li>
                    <li>Copy the long token string and paste it above</li>
                </ol>
            </div>
        </div>
    </div>

    <script>
        function updateCharCount() {
            const textarea = document.getElementById('token');
            const charCount = document.getElementById('charCount');
            const length = textarea.value.length;
            charCount.textContent = length + ' characters';

            if (length < 40) {
                charCount.style.color = '#e53e3e';
            } else if (length >= 40 && length < 80) {
                charCount.style.color = '#dd6b20';
            } else {
                charCount.style.color = '#38a169';
            }
        }

        // Update count on page load
        document.addEventListener('DOMContentLoaded', updateCharCount);

        // Auto-focus the textarea
        document.getElementById('token').focus();
    </script>
</body>
</html>