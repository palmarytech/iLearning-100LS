import UIKit
import AVFoundation

class ViewController: UIViewController, UIDocumentPickerDelegate, AVAudioPlayerDelegate, UITextFieldDelegate, UITextViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    @IBOutlet weak var startTimeField: UITextField!
    @IBOutlet weak var endTimeField: UITextField!
    @IBOutlet weak var loopCountField: UITextField!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var audioTextView: UITextView!
    @IBOutlet weak var volumeBoostSwitch: UISwitch!
    @IBOutlet weak var speedPicker: UIPickerView!
    
    var player: AVAudioPlayer?
    var audioURL: URL?
    var loopCount = 0
    var currentLoop = 0
    var timer: Timer?
    var currentAudioURL: URL?
    var initialDuration: Double = 0.0
    var isPaused: Bool = false
    let playbackSpeeds: [Float] = [1.0, 0.85, 0.75, 0.5] // 可选速度
    var selectedSpeed: Float = 1.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudioSession()
        startTimeField.delegate = self
        endTimeField.delegate = self
        loopCountField.delegate = self
        audioTextView.delegate = self
        
        // 配置速度选择器
        speedPicker.dataSource = self
        speedPicker.delegate = self
        speedPicker.selectRow(0, inComponent: 0, animated: false) // 默认选择 1x
        selectedSpeed = playbackSpeeds[0]
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        statusLabel.numberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        
        progressSlider.minimumValue = 0.0
        progressSlider.maximumValue = 1.0
        progressSlider.value = 0.0
        progressSlider.addTarget(self, action: #selector(sliderValueChanged(_:)), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        
        timeLabel.text = "00:00:00 / 00:00:00"
        audioTextView.text = "在此输入或粘贴音频文本"
        audioTextView.textColor = .gray
        audioTextView.layer.borderWidth = 1.0
        audioTextView.layer.borderColor = UIColor.lightGray.cgColor
        audioTextView.layer.cornerRadius = 5.0
        
        volumeBoostSwitch.isOn = false
        print("ViewController 已加载")
    }
    // UIPickerViewDataSource
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1 // 单列
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return playbackSpeeds.count // 行数等于速度选项数
    }

    // UIPickerViewDelegate
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(playbackSpeeds[row])x" // 显示为 "1x", "0.85x" 等
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedSpeed = playbackSpeeds[row] // 更新选中速度
        applyPlaybackSpeed() // 应用新速度
        print("选择播放速度: \(selectedSpeed)x")
    }
    private func applyPlaybackSpeed() {
        guard let player = player else { return }
        player.rate = selectedSpeed // 设置播放速度
    }
    
    func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("音频会话配置成功")
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
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio], asCopy: false)
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
            if (error as NSError).code == 260 {
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
        
        print("开始播放: start=\(startTime), end=\(endTime), loops=\(loops), speed=\(selectedSpeed)x")
        
        do {
            if player == nil || currentAudioURL != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
                player?.enableRate = true // 启用变速播放
                player?.currentTime = startTime
                loopCount = loops // 始终更新 loopCount
                currentLoop = 0
                progressSlider.value = 0.0
                currentAudioURL = url
                applyVolumeBoost()
                applyPlaybackSpeed() // 应用播放速度
                print("已加载新音频: \(url.lastPathComponent)")
            } else if !player!.isPlaying {
                loopCount = loops // 始终更新 loopCount
                if isPaused {
                    applyVolumeBoost()
                    applyPlaybackSpeed() // 应用播放速度
                    print("从暂停位置继续播放，当前时间: \(player!.currentTime)")
                } else {
                    player?.currentTime = startTime
                    currentLoop = 0 // 重置当前循环
                    applyVolumeBoost()
                    applyPlaybackSpeed() // 应用播放速度
                    print("从起始位置重新播放，设置时间为: \(startTime)")
                }
            }
            
            player?.play()
            statusLabel.text = "正在播放 (第 \(currentLoop + 1) 次 / \(loopCount))"
            isPaused = false
            
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
                
                
                let totalDuration = (endTime - startTime) / Double(self.selectedSpeed) // 调整时长
                let currentProgress = (currentTime - startTime) / totalDuration
                if !self.progressSlider.isTracking {
                    self.progressSlider.value = Float(max(0.0, min(1.0, currentProgress)))
                }
                self.timeLabel.text = "\(self.formatTime(currentTime)) / \(self.formatTime(endTime))"
                
                if currentTime >= endTime - 0.05 || !player.isPlaying {
                    self.currentLoop += 1
                    if self.currentLoop < self.loopCount {
                        player.currentTime = startTime
                        player.play()
                        self.progressSlider.value = 0.0
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
        guard let player = player else { return }
        player.stop()
        timer?.invalidate()
        player.currentTime = Double(startTimeField.text ?? "0") ?? 0.0
        statusLabel.text = "已停止"
        currentLoop = 0
        progressSlider.value = 0.0
        timeLabel.text = "00:00:00 / \(endTimeField.text != nil ? formatTime(Double(endTimeField.text!) ?? 0.0) : "00:00:00")"
        isPaused = false
        print("手动停止当前播放，时间重置为: \(player.currentTime)")
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
        isPaused = true
        print("音频暂停，当前时间: \(player.currentTime)")
    }
    
    @IBAction func clearTextTapped(_ sender: UIButton) {
        audioTextView.text = "在此输入或粘贴音频文本"
        audioTextView.textColor = .gray
        audioTextView.resignFirstResponder()
        print("音频文本已清空")
    }
    
    @IBAction func markStartTimeTapped(_ sender: UIButton) {
        guard let url = audioURL,
              let endTimeStr = endTimeField.text, let endTime = Double(endTimeStr),
              let startTimeStr = startTimeField.text, let startTime = Double(startTimeStr) else {
            print("音频未加载或时间输入无效，无法打点开始时间")
            statusLabel.text = "请先导入音频"
            return
        }
        
        let totalDuration = endTime - startTime
        let currentTime: Double
        if let player = player, player.isPlaying {
            currentTime = player.currentTime
        } else {
            currentTime = startTime + Double(progressSlider.value) * totalDuration
        }
        
        guard currentTime < endTime else {
            print("当前时间 (\(currentTime)) 不小于结束时间 (\(endTime))，无法设置为开始时间")
            return
        }
        
        startTimeField.text = String(format: "%.1f", currentTime)
        if let player = player {
            player.currentTime = currentTime
        } else if url != currentAudioURL {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.currentTime = currentTime
                currentAudioURL = url
            } catch {
                print("初始化播放器失败: \(error)")
            }
        }
        progressSlider.value = Float((currentTime - startTime) / totalDuration)
        timeLabel.text = "\(formatTime(currentTime)) / \(formatTime(endTime))"
        print("已将开始时间设置为: \(currentTime)")
    }
    
    @IBAction func markEndTimeTapped(_ sender: UIButton) {
        guard let url = audioURL,
              let startTimeStr = startTimeField.text, let startTime = Double(startTimeStr),
              let endTimeStr = endTimeField.text, let endTime = Double(endTimeStr) else {
            print("音频未加载或时间输入无效，无法打点结束时间")
            statusLabel.text = "请先导入音频"
            return
        }
        
        let totalDuration = endTime - startTime
        let currentTime: Double
        if let player = player, player.isPlaying {
            currentTime = player.currentTime
        } else {
            currentTime = startTime + Double(progressSlider.value) * totalDuration
        }
        
        guard currentTime > startTime else {
            print("当前时间 (\(currentTime)) 不大于开始时间 (\(startTime))，无法设置为结束时间")
            return
        }
        
        endTimeField.text = String(format: "%.1f", currentTime)
        if let player = player {
            player.currentTime = currentTime
        } else if url != currentAudioURL {
            do {
                player = try AVAudioPlayer(contentsOf: url)
                player?.currentTime = currentTime
                currentAudioURL = url
            } catch {
                print("初始化播放器失败: \(error)")
            }
        }
        progressSlider.value = Float((currentTime - startTime) / totalDuration)
        timeLabel.text = "\(formatTime(currentTime)) / \(formatTime(endTime))"
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
        progressSlider.value = 0.0
        timeLabel.text = "00:00:00 / \(formatTime(initialDuration))"
        if let player = player {
            player.currentTime = 0
        }
        print("时间已重置: 开始时间 = 0, 结束时间 = \(initialDuration)")
    }
    
    @IBAction func volumeBoostToggled(_ sender: UISwitch) {
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
    
    @objc func sliderValueChanged(_ sender: UISlider) {
        guard let startTimeStr = startTimeField.text, let startTime = Double(startTimeStr),
              let endTimeStr = endTimeField.text, let endTime = Double(endTimeStr) else { return }
        
        let totalDuration = endTime - startTime
        let newTime = startTime + Double(sender.value) * totalDuration
        if let player = player {
            player.currentTime = newTime
        }
        timeLabel.text = "\(formatTime(newTime)) / \(formatTime(endTime))"
        print("滑块拖动，当前时间设置为: \(newTime)")
    }
    
    @objc func sliderTouchUp(_ sender: UISlider) {
        guard let player = player else { return }
        if player.isPlaying {
            player.play()
            print("滑块松开，继续播放")
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("音频自然结束，flag: \(flag)")
        if currentLoop < loopCount - 1 {
            currentLoop += 1
            player.currentTime = Double(startTimeField.text ?? "0") ?? 0.0
            player.play()
            progressSlider.value = 0.0
            timeLabel.text = "\(formatTime(Double(startTimeField.text ?? "0") ?? 0.0)) / \(formatTime(Double(endTimeField.text ?? "0") ?? 0.0))"
            print("自然结束触发第 \(currentLoop + 1) 次循环")
        } else {
            statusLabel.text = "播放完成"
            timer?.invalidate()
            print("播放完成，总循环次数: \(loopCount)")
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
