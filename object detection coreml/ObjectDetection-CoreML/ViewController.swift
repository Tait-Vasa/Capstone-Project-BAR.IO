//
//  ViewController.swift
//  SSDMobileNet-CoreML
//
//  Created by GwakDoyoung on 01/02/2019.
//  Modified by Cole Johnson on 2025/10/29
//

import UIKit
import Vision
import CoreMedia

class ViewController: UIViewController {

    var popupHeightConstraint: NSLayoutConstraint!
    var popupPanGesture: UIPanGestureRecognizer!
    var isExpanded = false

    // MARK: - UI Properties
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var boxesView: DrawingBoundingBoxView!
    @IBOutlet weak var labelsTableView: UITableView!

    @IBOutlet weak var inferenceLabel: UILabel!
    @IBOutlet weak var etimeLabel: UILabel!
    @IBOutlet weak var fpsLabel: UILabel!
    @IBOutlet var bottomPopup: UIView!

    // Popup content
    var popupTableView: UITableView!
    var popupItems: [String] = ["Jack Daniels", "Jameson", "Patron"]
    var popupItemCodes: [String] = ["#A-1021", "#B-2042", "#C-3099"]

    // MARK: - Core ML model
    lazy var objectDectectionModel = { return try? mymodel() }()

    // MARK: - Vision Properties
    var request: VNCoreMLRequest?
    var visionModel: VNCoreMLModel?
    var isInferencing = false

    // MARK: - AV Property
    var videoCapture: VideoCapture!
    let semaphore = DispatchSemaphore(value: 1)
    var lastExecution = Date()

    // MARK: - TableView Data
    var predictions: [VNRecognizedObjectObservation] = []

    // MARK - Performance Measurement Property
    private let 👨‍🔧 = 📏()

    let maf1 = MovingAverageFilter()
    let maf2 = MovingAverageFilter()
    let maf3 = MovingAverageFilter()

    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // setup the model
        setUpModel()

        // setup camera
        setUpCamera()

        // setup delegate for performance measurement
        👨‍🔧.delegate = self

        // setup popup
        addBottomPopup()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.videoCapture.start()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.videoCapture.stop()
    }

    // MARK: - Setup Core ML
    func setUpModel() {
        guard let objectDectectionModel = objectDectectionModel else { fatalError("fail to load the model") }
        if let visionModel = try? VNCoreMLModel(for: objectDectectionModel.model) {
            self.visionModel = visionModel
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request?.imageCropAndScaleOption = .scaleFill
        } else {
            fatalError("fail to create vision model")
        }
    }

    // MARK: - SetUp Video
    func setUpCamera() {
        videoCapture = VideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 30
        videoCapture.setUp(sessionPreset: .vga640x480) { success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer {
                    self.videoPreview.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
            }
        }
    }

    // MARK: - Add Bottom Popup
    func addBottomPopup() {
        bottomPopup = UIView()
        bottomPopup.backgroundColor = UIColor.systemGray6.withAlphaComponent(0.5)
        bottomPopup.layer.cornerRadius = 20
        bottomPopup.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        bottomPopup.layer.masksToBounds = true

        view.addSubview(bottomPopup)
        bottomPopup.translatesAutoresizingMaskIntoConstraints = false

        popupHeightConstraint = bottomPopup.heightAnchor.constraint(equalToConstant: 300)

        NSLayoutConstraint.activate([
            bottomPopup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomPopup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomPopup.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            popupHeightConstraint
        ])

        // ---- Transparent Header ----
        let headerView = UIView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = UIColor.clear  // transparent now
        bottomPopup.addSubview(headerView)

        // Spinner (loading wheel)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(spinner)

        // Icon
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.image = UIImage(named: "itemIcon1") // Jack Daniels image
        headerView.addSubview(iconImageView)

        // Text stack (name + item code + progress bar)
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

        let progressView = UIProgressView(progressViewStyle: .default)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0.65
        progressView.tintColor = .systemBlue
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true

        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(itemCodeLabel)
        textStack.addArrangedSubview(progressView)

        // Layout constraints for header
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

        // ---- Table view ----
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PopupItemCell")
        tableView.separatorInset = .zero
        tableView.showsVerticalScrollIndicator = true
        bottomPopup.addSubview(tableView)
        self.popupTableView = tableView

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 5),
            tableView.leadingAnchor.constraint(equalTo: bottomPopup.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: bottomPopup.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomPopup.bottomAnchor, constant: -70)
        ])

        // ---- Save button ----
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

        saveButton.addTarget(self, action: #selector(saveInventoryTapped), for: .touchUpInside)
    }

    @objc func saveInventoryTapped() {
        let alert = UIAlertController(title: "Success", message: "Save successfully!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        resizePreviewLayer()
    }

    func resizePreviewLayer() {
        videoCapture.previewLayer?.frame = videoPreview.bounds
    }
}

// MARK: - Table View Data Source + Delegate
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == popupTableView {
            return popupItems.count
        } else {
            return predictions.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == popupTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PopupItemCell", for: indexPath)
            cell.selectionStyle = .none

            for subview in cell.contentView.subviews { subview.removeFromSuperview() }

            // Number label
            let numberLabel = UILabel()
            numberLabel.translatesAutoresizingMaskIntoConstraints = false
            numberLabel.font = UIFont.boldSystemFont(ofSize: 18)
            numberLabel.textAlignment = .center
            numberLabel.textColor = .secondaryLabel
            cell.contentView.addSubview(numberLabel)

            // Icon container
            let iconContainer = UIView()
            iconContainer.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(iconContainer)

            let iconImageView = UIImageView()
            iconImageView.translatesAutoresizingMaskIntoConstraints = false
            iconImageView.contentMode = .scaleAspectFit
            iconImageView.image = UIImage(named: "itemIcon\(indexPath.row + 1)")
            iconContainer.addSubview(iconImageView)

            // Stack for title + item code
            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2
            textStack.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(textStack)

            let titleLabel = UILabel()
            titleLabel.text = popupItems[indexPath.row]
            titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)

            let itemCodeLabel = UILabel()
            itemCodeLabel.text = popupItemCodes[indexPath.row]
            itemCodeLabel.font = UIFont.systemFont(ofSize: 13)
            itemCodeLabel.textColor = UIColor.darkGray

            textStack.addArrangedSubview(titleLabel)
            textStack.addArrangedSubview(itemCodeLabel)

            // Percentage label
            let percentageLabel = UILabel()
            percentageLabel.translatesAutoresizingMaskIntoConstraints = false
            percentageLabel.font = UIFont.boldSystemFont(ofSize: 16)
            percentageLabel.textAlignment = .right
            cell.contentView.addSubview(percentageLabel)

            // Assign percentage and color
            switch indexPath.row {
            case 0:
                percentageLabel.text = "85%"
                percentageLabel.textColor = .systemGreen
            case 1:
                percentageLabel.text = "57%"
                percentageLabel.textColor = .systemOrange
            case 2:
                percentageLabel.text = "21%"
                percentageLabel.textColor = .systemRed
            default:
                percentageLabel.text = "-"
                percentageLabel.textColor = .secondaryLabel
            }

            // Assign numbering
            let totalItems = popupItems.count
            numberLabel.text = "\(totalItems - indexPath.row)"

            // Constraints
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

                percentageLabel.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                percentageLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),

                textStack.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -8)
            ])

            return cell
        } else {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "InfoCell") else {
                return UITableViewCell()
            }
            let rectString = predictions[indexPath.row].boundingBox.toString(digit: 2)
            let confidence = predictions[indexPath.row].labels.first?.confidence ?? -1
            let confidenceString = String(format: "%.3f", confidence)

            cell.textLabel?.text = predictions[indexPath.row].label ?? "N/A"
            cell.detailTextLabel?.text = "\(rectString), \(confidenceString)"
            return cell
        }
    }
}

// MARK: - VideoCaptureDelegate
extension ViewController: VideoCaptureDelegate {
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        if !self.isInferencing, let pixelBuffer = pixelBuffer {
            self.isInferencing = true
            self.👨‍🔧.🎬👏()
            self.predictUsingVision(pixelBuffer: pixelBuffer)
        }
    }
}

extension ViewController {
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        guard let request = request else { fatalError() }
        self.semaphore.wait()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try? handler.perform([request])
    }

    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        self.👨‍🔧.🏷(with: "endInference")
        if let predictions = request.results as? [VNRecognizedObjectObservation] {
            self.predictions = predictions
            DispatchQueue.main.async {
                self.boxesView.predictedObjects = predictions
                self.labelsTableView.reloadData()
                self.👨‍🔧.🎬🤚()
                self.isInferencing = false
            }
        } else {
            self.👨‍🔧.🎬🤚()
            self.isInferencing = false
        }
        self.semaphore.signal()
    }
}

// MARK: - Performance Measurement Delegate
extension ViewController: 📏Delegate {
    func updateMeasure(inferenceTime: Double, executionTime: Double, fps: Int) {
        DispatchQueue.main.async {
            self.maf1.append(element: Int(inferenceTime * 1000.0))
            self.maf2.append(element: Int(executionTime * 1000.0))
            self.maf3.append(element: fps)

            self.inferenceLabel.text = "inference: \(self.maf1.averageValue) ms"
            self.etimeLabel.text = "execution: \(self.maf2.averageValue) ms"
            self.fpsLabel.text = "fps: \(self.maf3.averageValue)"
        }
    }
}

// MARK: - Moving Average Filter
class MovingAverageFilter {
    private var arr: [Int] = []
    private let maxCount = 10

    public func append(element: Int) {
        arr.append(element)
        if arr.count > maxCount {
            arr.removeFirst()
        }
    }

    public var averageValue: Int {
        guard !arr.isEmpty else { return 0 }
        let sum = arr.reduce(0) { $0 + $1 }
        return Int(Double(sum) / Double(arr.count))
    }
}
