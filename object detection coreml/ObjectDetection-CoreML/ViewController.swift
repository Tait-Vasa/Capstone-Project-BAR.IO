//
//  ViewController.swift
//  SSDMobileNet-CoreML
//
//  Created by GwakDoyoung on 01/02/2019.
//  Modified by Cole Johnson on 2025/11/20
//

import UIKit
import Vision
import CoreMedia

/// Main view controller that handles camera capture, Vision + CoreML inference,
/// and a bottom popup UI used for scanning bottles into an inventory list.
class ViewController: UIViewController {

    // MARK: - UI Outlets (from storyboard)
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var boxesView: DrawingBoundingBoxView!
    @IBOutlet weak var labelsTableView: UITableView!

    // MARK: - UI Properties created programmatically
    var bottomPopup: UIView!
    private var scanStatusLabel: UILabel!
    private var headerView: UIView!
    private var progressView: UIProgressView!
    private var popupTableView: UITableView!

    // Popup data
    private var popupItems: [String] = ["Jack Daniels", "Jameson", "Patron"]
    private var popupItemCodes: [String] = ["#A-1021", "#B-2042", "#C-3099"]

    // ADDED → Percentages matching bottle names
    private var popupPercentages: [Int] = [91, 53, 15]

    // MARK: - Popup sizing & gestures
    private var popupHeightConstraint: NSLayoutConstraint!
    private var popupPanGesture: UIPanGestureRecognizer!

    // MARK: - Detection / scanning state
    private var bottleInView = false
    private var lastBottleDetectionTime: TimeInterval = 0
    private var progressTimer: Timer?
    private var progressElapsed: TimeInterval = 0.0
    private let progressDuration: TimeInterval = 2.5

    private var currentBottleIndex = 0
    private var scannedBottles: [(name: String, code: String, icon: String)] = []

    // MARK: - CoreML / Vision
    lazy private var objectDetectionModel: mymodel? = {
        return try? mymodel()
    }()
    private var request: VNCoreMLRequest?
    private var visionModel: VNCoreMLModel?
    private var isInferencing = false
    private let semaphore = DispatchSemaphore(value: 1)
    private var videoCapture: VideoCapture!
    private var predictions: [VNRecognizedObjectObservation] = []

    // MARK: - View lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpModel()
        setUpCamera()
        
        let blackBackgroundView = UIView()
        blackBackgroundView.backgroundColor = .black
        blackBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(blackBackgroundView, at: 0)

        NSLayoutConstraint.activate([
            blackBackgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            blackBackgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blackBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blackBackgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        addScanStatusLabel()
        setScanStatus("Ready to Scan")
        addBottomPopup()
        labelsTableView.isHidden = true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        videoCapture?.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoCapture?.stop()
    }

    // MARK: - Model & Vision setup
    private func setUpModel() {
        guard let mlModel = objectDetectionModel else { fatalError("Failed to load Core ML model.") }
        do {
            let vModel = try VNCoreMLModel(for: mlModel.model)
            self.visionModel = vModel
            let request = VNCoreMLRequest(model: vModel, completionHandler: visionRequestDidComplete)
            request.imageCropAndScaleOption = .scaleFill
            self.request = request
        } catch {
            fatalError("Failed to create VNCoreMLModel: \(error)")
        }
    }

    // MARK: - Camera setup
    private func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { [weak self] success in
            guard let self = self else { return }
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
            }
        }
    }

    private func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }

    // MARK: - Scan status label
    private func addScanStatusLabel() {
        scanStatusLabel = UILabel()
        scanStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        scanStatusLabel.textAlignment = .center
        scanStatusLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        scanStatusLabel.textColor = .white
        scanStatusLabel.numberOfLines = 1
        scanStatusLabel.alpha = 1.0
        videoPreview.addSubview(scanStatusLabel)

        NSLayoutConstraint.activate([
            scanStatusLabel.topAnchor.constraint(equalTo: videoPreview.topAnchor, constant: 12),
            scanStatusLabel.centerXAnchor.constraint(equalTo: videoPreview.centerXAnchor)
        ])
    }

    private func setScanStatus(_ text: String) {
        DispatchQueue.main.async {
            UIView.transition(with: self.scanStatusLabel, duration: 0.18, options: .transitionCrossDissolve) {
                self.scanStatusLabel.text = text
            }
        }
    }

    // MARK: - Bottom popup UI
    private func addBottomPopup() {
        bottomPopup = UIView()
        bottomPopup.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
        bottomPopup.layer.cornerRadius = 20
        bottomPopup.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomPopup.layer.masksToBounds = true
        bottomPopup.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomPopup)

        popupHeightConstraint = bottomPopup.heightAnchor.constraint(equalToConstant: 300)
        NSLayoutConstraint.activate([
            bottomPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPopup.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            popupHeightConstraint
        ])
        
        let contentBackground = UIView()
        contentBackground.backgroundColor = UIColor.systemGray6
        contentBackground.layer.cornerRadius = 20
        contentBackground.translatesAutoresizingMaskIntoConstraints = false
        bottomPopup.addSubview(contentBackground)
        bottomPopup.sendSubviewToBack(contentBackground)

        NSLayoutConstraint.activate([
            contentBackground.topAnchor.constraint(equalTo: bottomPopup.topAnchor, constant: 75),
            contentBackground.leadingAnchor.constraint(equalTo: bottomPopup.leadingAnchor),
            contentBackground.trailingAnchor.constraint(equalTo: bottomPopup.trailingAnchor),
            contentBackground.bottomAnchor.constraint(equalTo: bottomPopup.bottomAnchor)
        ])

        // Header
        headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.clear
        headerView.alpha = 0
        bottomPopup.addSubview(headerView)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        headerView.addSubview(spinner)

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(named: "itemIcon1")
        headerView.addSubview(iconImageView)

        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(textStack)

        let nameLabel = UILabel()
        nameLabel.text = "Jack Daniels"
        nameLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        let itemCodeLabel = UILabel()
        itemCodeLabel.text = "#A-1021"
        itemCodeLabel.font = UIFont.systemFont(ofSize: 12)
        itemCodeLabel.textColor = UIColor.darkGray

        progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0.0

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(itemCodeLabel)
        textStack.addArrangedSubview(progressView)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: bottomPopup.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: bottomPopup.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: bottomPopup.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 70),

            spinner.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            spinner.widthAnchor.constraint(equalToConstant: 25),

            iconImageView.leadingAnchor.constraint(equalTo: spinner.trailingAnchor, constant: 8),
            iconImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 45),
            iconImageView.heightAnchor.constraint(equalToConstant: 45),

            textStack.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -10),
            textStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            progressView.heightAnchor.constraint(equalToConstant: 4)
        ])

        // Table
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PopupItemCell")
        bottomPopup.addSubview(tableView)
        self.popupTableView = tableView

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 5),
            tableView.leadingAnchor.constraint(equalTo: bottomPopup.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: bottomPopup.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomPopup.bottomAnchor, constant: -70)
        ])

        // Save button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Inventory", for: .normal)
        saveButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        saveButton.backgroundColor = UIColor.systemGreen
        saveButton.tintColor = .white
        saveButton.layer.cornerRadius = 10
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        bottomPopup.addSubview(saveButton)

        NSLayoutConstraint.activate([
            saveButton.leadingAnchor.constraint(equalTo: bottomPopup.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: bottomPopup.trailingAnchor, constant: -20),
            saveButton.bottomAnchor.constraint(equalTo: bottomPopup.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            saveButton.heightAnchor.constraint(equalToConstant: 50)
        ])

        addBottomPopupPanGesture()
        saveButton.addTarget(self, action: #selector(saveInventoryTapped), for: .touchUpInside)
    }

    private func addBottomPopupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePopupPan(_:)))
        bottomPopup.addGestureRecognizer(panGesture)
        self.popupPanGesture = panGesture
    }

    @objc private func handlePopupPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        gesture.setTranslation(.zero, in: view)
        let screenHeight = view.bounds.height
        let snapFractions: [CGFloat] = [1/8, 2/8, 3/8, 4/8, 5/8, 6/8, 7/8]
        let snapHeights = snapFractions.map { $0 * screenHeight }

        var newHeight = popupHeightConstraint.constant - translation.y
        newHeight = max(snapHeights.first!, min(snapHeights.last!, newHeight))
        popupHeightConstraint.constant = newHeight

        UIView.animate(withDuration: 0.1) { self.view.layoutIfNeeded() }

        if gesture.state == .ended {
            let closest = snapHeights.min(by: { abs($0 - newHeight) < abs($1 - newHeight) }) ?? newHeight
            UIView.animate(withDuration: 0.2) {
                self.popupHeightConstraint.constant = closest
                self.view.layoutIfNeeded()
            }
        }
    }

    // MARK: - Save Inventory
    @objc private func saveInventoryTapped() {
        guard !scannedBottles.isEmpty else {
            let alert = UIAlertController(title: "No items", message: "You haven't scanned any bottles yet.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let scannedListString = scannedBottles.map { "\($0.name) (\($0.code))" }.joined(separator: "\n")

        let alert = UIAlertController(title: "Scanned Bottles", message: scannedListString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Continue Scanning", style: .default))
        alert.addAction(UIAlertAction(title: "Submit List", style: .destructive, handler: { _ in
            self.scannedBottles.removeAll()
            self.popupTableView.reloadData()
            self.currentBottleIndex = 0
            self.bottleInView = false
            self.progressElapsed = 0
            self.progressView.progress = 0
            self.setScanStatus("Ready to Scan")
            self.hideHeader()
        }))
        present(alert, animated: true)
    }

    // MARK: - Header show/hide and scanning
    private func showHeaderForNextBottle() {
        guard currentBottleIndex < popupItems.count else { return }
        setScanStatus("Scanning…")
        let name = popupItems[currentBottleIndex]
        let code = popupItemCodes[currentBottleIndex]
        let iconName = "itemIcon\(currentBottleIndex + 1)"

        if let textStack = headerView.subviews.compactMap({ $0 as? UIStackView }).first,
           let nameLabel = textStack.arrangedSubviews[0] as? UILabel,
           let itemCodeLabel = textStack.arrangedSubviews[1] as? UILabel {
            nameLabel.text = name
            itemCodeLabel.text = code
        }

        if let iconImageView = headerView.subviews.compactMap({ $0 as? UIImageView }).first {
            iconImageView.image = UIImage(named: iconName)
        }

        DispatchQueue.main.async {
            self.headerView.isHidden = false
            UIView.animate(withDuration: 0.25) { self.headerView.alpha = 1 }
            self.progressTimer?.invalidate()
            self.progressElapsed = 0
            self.progressView.progress = 0

            self.progressTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
                self.progressElapsed += 0.02
                let progress = Float(self.progressElapsed / self.progressDuration)
                self.progressView.progress = min(progress, 1.0)
                if self.progressElapsed >= self.progressDuration {
                    timer.invalidate()
                    self.finishCurrentBottleScan()
                }
            }
        }
    }

    private func finishCurrentBottleScan() {
        guard currentBottleIndex < popupItems.count else { return }
        setScanStatus("Scan Complete!")
        let name = popupItems[currentBottleIndex]
        let code = popupItemCodes[currentBottleIndex]
        let icon = "itemIcon\(currentBottleIndex + 1)"
        scannedBottles.insert((name, code, icon), at: 0)

        DispatchQueue.main.async { self.popupTableView.reloadData() }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hideHeader()
            self.currentBottleIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { self.setScanStatus("Ready to Scan") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.currentBottleIndex < self.popupItems.count { self.bottleInView = false }
            }
        }
    }

    private func hideHeader() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.25, animations: { self.headerView.alpha = 0 }, completion: { _ in
                self.headerView.isHidden = true
                self.progressTimer?.invalidate()
                self.progressElapsed = 0
                self.progressView.progress = 0
                self.setScanStatus("Ready to Scan")
            })
        }
    }
}

// MARK: - UITableView DataSource & Delegate

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == popupTableView ? scannedBottles.count : predictions.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { return 70 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if tableView == popupTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PopupItemCell", for: indexPath)
            cell.selectionStyle = .none

            for subview in cell.contentView.subviews { subview.removeFromSuperview() }

            let numberLabel = UILabel()
            numberLabel.translatesAutoresizingMaskIntoConstraints = false
            numberLabel.font = UIFont.boldSystemFont(ofSize: 18)
            numberLabel.textAlignment = .center
            numberLabel.textColor = .secondaryLabel
            cell.contentView.addSubview(numberLabel)

            let iconContainer = UIView()
            iconContainer.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(iconContainer)

            let iconImageView = UIImageView()
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.contentMode = .scaleAspectFit
            iconContainer.addSubview(iconImageView)

            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2
            textStack.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(textStack)

            let bottle = scannedBottles[indexPath.row]
            let titleLabel = UILabel()
            titleLabel.text = bottle.name
            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)

            let itemCodeLabel = UILabel()
            itemCodeLabel.text = bottle.code
            itemCodeLabel.font = UIFont.systemFont(ofSize: 13)
            itemCodeLabel.textColor = UIColor.darkGray

            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(itemCodeLabel)

            iconImageView.image = UIImage(named: bottle.icon)
            numberLabel.text = "\(scannedBottles.count - indexPath.row)"

            // ===== ADDED PERCENT LABEL =====
            let percentLabel = UILabel()
            percentLabel.translatesAutoresizingMaskIntoConstraints = false
            percentLabel.font = UIFont.boldSystemFont(ofSize: 18)
            percentLabel.textAlignment = .right
            cell.contentView.addSubview(percentLabel)

            let name = bottle.name
            var pct = 0
            if let idx = popupItems.firstIndex(of: name) {
                pct = popupPercentages[idx]
            }
            percentLabel.text = "\(pct)%"

            if pct >= 80 { percentLabel.textColor = .systemGreen }
            else if pct >= 30 { percentLabel.textColor = .systemOrange }
            else { percentLabel.textColor = .systemRed }

            // Layout
            NSLayoutConstraint.activate([
                numberLabel.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 10),
                numberLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                numberLabel.widthAnchor.constraint(equalToConstant: 25),

                iconContainer.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 8),
                iconContainer.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                iconContainer.widthAnchor.constraint(equalToConstant: 60),
                iconContainer.heightAnchor.constraint(equalToConstant: 60),

                iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: 50),
                iconImageView.heightAnchor.constraint(equalToConstant: 50),

                textStack.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
                textStack.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),

                // Percentage anchored to right
                percentLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                percentLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                percentLabel.widthAnchor.constraint(equalToConstant: 60),

                // Make text stack stop before percent
                textStack.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -10)
            ])

            return cell
        }

        // Default prediction cell
        let reuseId = "InfoCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseId) ?? UITableViewCell(style: .default, reuseIdentifier: reuseId)
        cell.textLabel?.text = predictions[indexPath.row].labels.first?.identifier ?? "N/A"
        return cell
    }
}

// MARK: - VideoCaptureDelegate
extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        guard !isInferencing, let pixelBuffer = pixelBuffer else { return }
        isInferencing = true
        predictUsingVision(pixelBuffer: pixelBuffer)
    }
}

// MARK: - Vision methods
extension ViewController {
    private func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = self.request else { fatalError("Vision request not configured.") }
        semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }

    private func visionRequestDidComplete(request: VNRequest, error: Error?) {
        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            self.predictions = predictions
            DispatchQueue.main.async {
                self.boxesView.predictedObjects = predictions
                self.labelsTableView.reloadData()

                let bottleDetected = predictions.contains { $0.labels.first?.identifier.lowercased() == "botte" }
                let currentTime = Date().timeIntervalSince1970

                if bottleDetected {
                    if !self.bottleInView && self.progressElapsed == 0 {
                        self.bottleInView = true
                        self.showHeaderForNextBottle()
                    }
                    self.lastBottleDetectionTime = currentTime
                } else if self.bottleInView && currentTime - self.lastBottleDetectionTime > 0.5 {
                    self.bottleInView = false
                    self.progressTimer?.invalidate()
                    self.progressElapsed = 0
                    self.progressView.progress = 0
                    self.hideHeader()
                    self.setScanStatus("Ready to Scan")
                }

                self.isInferencing = false
            }
        } else {
            DispatchQueue.main.async {
                self.bottleInView = false
                self.hideHeader()
                self.setScanStatus("Ready to Scan")
            }
            self.isInferencing = false
        }
        semaphore.signal()
    }
}
