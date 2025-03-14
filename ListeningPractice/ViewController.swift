import UIKit
import AVFoundation

class ViewController: UIViewController, UIDocumentPickerDelegate, AVAudioPlayerDelegate, UITextFieldDelegate, UITextViewDelegate {
    
    @IBOutlet weak var startTimeField: UITextField!
    @IBOutlet weak var endTimeField: UITextField!
    @IBOutlet weak var loopCountField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var audioTextView: UITextView!
    @IBOutlet weak var volumeBoostSwitch: UISwitch!
    
    var player: AVAudioPlayer?
    var audioURL: URL?
    var loopCount = 0
    var currentLoop = 0
    var timer: Timer?
    var currentAudioURL: URL?
    var initialDuration: Double = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        startTimeField.delegate = self
        endTimeField.delegate = self
        loopCountField.delegate = self
        audioTextView.delegate = self
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        
        progressView.progress = 0.0
        progressView.progressTintColor = .blue
        progressView.trackTintColor = .lightGray
        
        timeLabel.text = "00:00:00 / 00:00:00"
        audioTextView.text = "在此输入或粘贴音频文本"
        audioTextView.textColor = .gray
        audioTextView.layer.borderWidth = 1.0
        audioTextView.layer.borderColor = UIColor.lightGray.cgColor
        audioTextView.layer.cornerRadius = 5.0
        
        volumeBoostSwitch.isOn = false
        print("ViewController 已加载")
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话配置失败: \(error)")
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, secs)
    }
    
    @IBAction func importFile(_ sender: UIButton) {
        view.endEditing(true)
        print("导入文件按钮点击")
        
        statusLabel.text = "正在打开文件选择器..."
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: false) // 改为 asCopy: false
        documentPicker.delegate = self
        documentPicker.shouldShowFileExtensions = true
        present(documentPicker, animated: true) {
            self.statusLabel.text = "正在加载文件（可能需要下载）..."
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                guard let self = self else { return }
                if self.presentedViewController is UIDocumentPickerViewController {
                    self.statusLabel.text = "导入超时，请检查网络或确保文件已下载"
                    print("导入超时，可能卡在选择页面")
                }
            }
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("文件选择器回调触发，URLs: \(urls)")
        guard let selectedURL = urls.first else {
            print("未选择文件")
            statusLabel.text = "未选择文件"
            return
        }
        
        let didStartAccessing = selectedURL.startAccessingSecurityScopedResource()
        print("开始访问权限: \(didStartAccessing) for \(selectedURL)")
        if !didStartAccessing {
            print("无法获取文件访问权限: \(selectedURL)")
            statusLabel.text = "导入失败: 无法获取文件访问权限"
            return
        }
        
        do {
            let _ = try selectedURL.checkResourceIsReachable()
            
            // 手动复制文件到应用沙盒
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsDirectory.appendingPathComponent(selectedURL.lastPathComponent)
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: selectedURL, to: destinationURL)
            print("文件已手动复制到: \(destinationURL)")
            
            handleAudioFile(destinationURL, originalName: selectedURL.lastPathComponent)
        } catch {
            print("无法访问或复制文件: \(error)")
            if (error as NSError).code == 260 { // 文件未找到
                statusLabel.text = "导入失败: 文件未下载，请在 OneDrive 中设为离线可用"
            } else {
                statusLabel.text = "导入失败: \(error.localizedDescription)"
            }
        }
        
        selectedURL.stopAccessingSecurityScopedResource()
        print("权限释放: \(selectedURL)")
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        statusLabel.text = "导入已取消"
        print("用户取消了文件选择")
    }
    
    private func handleAudioFile(_ url: URL, originalName: String) {
        audioURL = url
        statusLabel.text = "文件已导入: \(originalName)"
        print("文件导入成功: \(url)")
        
        do {
            let tempPlayer = try AVAudioPlayer(contentsOf: url)
            let duration = tempPlayer.duration
            initialDuration = duration
            endTimeField.text = String(format: "%.1f", duration)
            startTimeField.text = "0"
            loopCountField.text = "100"
            timeLabel.text = "00:00:00 / \(formatTime(duration))"
            print("音频时长: \(duration) 秒")
            
            if let player = player, player.isPlaying {
                stopCurrentAudio()
                playAudio()
            }
        } catch {
            print("获取时长失败: \(error)")
            endTimeField.text = ""
            startTimeField.text = "0"
            loopCountField.text = "100"
            timeLabel.text = "00:00:00 / 00:00:00"
            statusLabel.text = "导入失败，请检查文件: \(error.localizedDescription)"
        }
    }
    
    private func playAudio() {
        guard let url = audioURL,
              let startTimeStr = startTimeField.text, let startTime = Double(startTimeStr),
              let endTimeStr = endTimeField.text, let endTime = Double(endTimeStr),
              let loopCountStr = loopCountField.text, let loops = Int(loopCountStr) else {
            statusLabel.text = "请检查输入"
            print("输入解析失败: start=\(startTimeField.text ?? "nil"), end=\(endTimeField.text ?? "nil"), loops=\(loopCountField.text ?? "nil")")
            return
        }
        
        print("开始播放: start=\(startTime), end=\(endTime), loops=\(loops)")
        
        do {
            if player == nil || currentAudioURL != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
                player?.currentTime = startTime
                loopCount = loops
                currentLoop = 0
                progressView.progress = 0.0
                currentAudioURL = url
                applyVolumeBoost()
                print("已加载新音频: \(url.lastPathComponent)")
            } else if !player!.isPlaying {
                player?.currentTime = startTime
                applyVolumeBoost()
                print("从停止或暂停位置重新播放，设置时间为: \(startTime)")
            }
            
            player?.play()
            statusLabel.text = "正在播放 (第 \(currentLoop + 1) 次 / \(loopCount))"
            
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                guard let self = self, let player = self.player else {
                    timer.invalidate()
                    print("播放器或 self 已释放，停止定时器")
                    return
                }
                let currentTime = player.currentTime
                print("当前时间: \(currentTime), 结束时间: \(endTime), 当前循环: \(self.currentLoop + 1)/\(self.loopCount)")
                statusLabel.text = "正在播放 (第 \(self.currentLoop + 1) 次 / \(self.loopCount))"
                
                let totalDuration = endTime - startTime
                let currentProgress = (currentTime - startTime) / totalDuration
                self.progressView.progress = Float(max(0.0, min(1.0, currentProgress)))
                self.timeLabel.text = "\(self.formatTime(currentTime)) / \(self.formatTime(endTime))"
                
                if currentTime >= endTime - 0.05 || !player.isPlaying {
                    self.currentLoop += 1
                    if self.currentLoop < self.loopCount {
                        player.currentTime = startTime
                        player.play()
                        self.progressView.progress = 0.0
                        self.timeLabel.text = "\(self.formatTime(startTime)) / \(self.formatTime(endTime))"
                        print("开始第 \(self.currentLoop + 1) 次循环")
                    } else {
                        player.stop()
                        statusLabel.text = "播放完成"
                        timer.invalidate()
                        print("播放完成，总循环次数: \(self.loopCount)")
                    }
                }
            }
        } catch {
            statusLabel.text = "播放失败: \(error)"
            print("播放失败: \(error)")
        }
    }
    
    private func stopCurrentAudio() {
        player?.stop()
        timer?.invalidate()
        statusLabel.text = "已停止"
        currentLoop = 0
        progressView.progress = 0.0
        timeLabel.text = "00:00:00 / \(endTimeField.text != nil ? formatTime(Double(endTimeField.text!) ?? 0.0) : "00:00:00")"
        print("手动停止当前播放")
    }
    
    @IBAction func playTapped(_ sender: UIButton) {
        print("playTapped 被点击")
        view.endEditing(true)
        playAudio()
    }
    
    @IBAction func stopTapped(_ sender: UIButton) {
        stopCurrentAudio()
    }
    
    @IBAction func pauseTapped(_ sender: UIButton) {
        guard let player = player, player.isPlaying else {
            print("没有正在播放的音频")
            return
        }
        player.pause()
        timer?.invalidate()
        statusLabel.text = "已暂停 (第 \(currentLoop + 1) 次 / \(loopCount))"
        print("音频暂停，当前时间: \(player.currentTime)")
    }
    
    @IBAction func clearTextTapped(_ sender: UIButton) {
        audioTextView.text = "在此输入或粘贴音频文本"
        audioTextView.textColor = .gray
        audioTextView.resignFirstResponder()
        print("音频文本已清空")
    }
    
    @IBAction func markStartTimeTapped(_ sender: UIButton) {
        guard let player = player, player.isPlaying else {
            print("音频未播放，无法打点开始时间")
            return
        }
        let currentTime = player.currentTime
        guard let endTime = Double(endTimeField.text ?? "0"), currentTime < endTime else {
            print("当前时间 (\(currentTime)) 不小于结束时间 (\(endTimeField.text ?? "N/A"))，无法设置为开始时间")
            return
        }
        startTimeField.text = String(format: "%.1f", currentTime)
        player.currentTime = currentTime
        progressView.progress = 0.0
        timeLabel.text = "\(formatTime(currentTime)) / \(formatTime(endTime))"
        print("已将开始时间设置为: \(currentTime)")
    }
    
    @IBAction func markEndTimeTapped(_ sender: UIButton) {
        guard let player = player, player.isPlaying else {
            print("音频未播放，无法打点结束时间")
            return
        }
        let currentTime = player.currentTime
        guard let startTime = Double(startTimeField.text ?? "0"), currentTime > startTime else {
            print("当前时间 (\(currentTime)) 不大于开始时间 (\(startTimeField.text ?? "N/A"))，无法设置为结束时间")
            return
        }
        endTimeField.text = String(format: "%.1f", currentTime)
        timeLabel.text = "\(formatTime(player.currentTime)) / \(formatTime(currentTime))"
        print("已将结束时间设置为: \(currentTime)")
    }
    
    @IBAction func resetTimeTapped(_ sender: UIButton) {
        guard initialDuration > 0 else {
            print("未导入音频，无法重置时间")
            statusLabel.text = "请先导入音频"
            return
        }
        startTimeField.text = "0"
        endTimeField.text = String(format: "%.1f", initialDuration)
        progressView.progress = 0.0
        timeLabel.text = "00:00:00 / \(formatTime(initialDuration))"
        if let player = player, player.isPlaying {
            player.currentTime = 0
        }
        print("时间已重置: 开始时间 = 0, 结束时间 = \(initialDuration)")
    }
    
    @IBAction func volumeBoostToggled(_ sender: UISwitch
                                      
) {
        applyVolumeBoost()
        print("音量增益设置为: \(sender.isOn ? "开启" : "关闭")")
    }
    
    private func applyVolumeBoost() {
        guard let player = player else { return }
        if volumeBoostSwitch.isOn {
            player.volume = 2.0
        } else {
            player.volume = 1.0
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("音频自然结束，flag: \(flag)")
        if currentLoop < loopCount - 1 {
            currentLoop += 1
            player.currentTime = Double(startTimeField.text ?? "0") ?? 0.0
            player.play()
            progressView.progress = 0.0
            timeLabel.text = "\(formatTime(Double(startTimeField.text ?? "0") ?? 0.0)) / \(formatTime(Double(endTimeField.text ?? "0") ?? 0.0))"
            print("自然结束触发第 \(currentLoop + 1) 次循环")
        } else {
            statusLabel.text = "播放完成"
            timer?.invalidate()
            print("自然结束完成，总循环次数: \(loopCount)")
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "."))
        let characterSet = CharacterSet(charactersIn: string)
        return allowedCharacters.isSuperset(of: characterSet)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .gray {
            textView.text = ""
            textView.textColor = .black
        }
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "在此输入或粘贴音频文本"
            textView.textColor = .gray
        }
        textView.resignFirstResponder()
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}
