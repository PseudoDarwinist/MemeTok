import UIKit

class MemeDetailViewController: UIViewController {
    private let meme: RedditPost
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()
    
    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.textColor = .white
        return label
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    init(meme: RedditPost) {
        self.meme = meme
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadImage()
        setupGestures()
        
        // Set navigation bar to be transparent
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.isTranslucent = true
        navigationController?.view.backgroundColor = .clear
        
        // Set navigation bar items to white
        navigationController?.navigationBar.tintColor = .white
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Configure scroll view
        scrollView.backgroundColor = .black
        scrollView.frame = view.bounds
        scrollView.contentInsetAdjustmentBehavior = .never
        
        // Configure image view
        imageView.backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        
        view.addSubview(scrollView)
        scrollView.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(activityIndicator)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            titleLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Configure title label with shadow for better visibility
        titleLabel.textColor = .white
        titleLabel.shadowColor = .black
        titleLabel.shadowOffset = CGSize(width: 1, height: 1)
        titleLabel.text = meme.title
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        // Add gradient background to title label for better readability
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.7).cgColor]
        gradientLayer.locations = [0.0, 1.0]
        titleLabel.layer.insertSublayer(gradientLayer, at: 0)
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        
        // Add share button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareButtonTapped)
        )
    }
    
    private func setupGestures() {
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
    }
    
    private func loadImage() {
        activityIndicator.startAnimating()
        
        guard let url = URL(string: meme.url) else {
            showError(message: "Invalid image URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.activityIndicator.stopAnimating()
                
                if let error = error {
                    self?.showError(message: "Failed to load image: \(error.localizedDescription)")
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    self?.showError(message: "Invalid server response")
                    return
                }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    self?.showError(message: "Invalid image data")
                    return
                }
                
                self?.imageView.image = image
                self?.updateZoomScaleForSize(image.size)
                
                // Add subtle animation when image loads
                self?.imageView.alpha = 0
                UIView.animate(withDuration: 0.3) {
                    self?.imageView.alpha = 1
                }
            }
        }
        task.resume()
    }
    
    private func showError(message: String) {
        activityIndicator.stopAnimating()
        
        let alert = UIAlertController(title: "Error",
                                     message: message,
                                     preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    private func updateZoomScaleForSize(_ imageSize: CGSize) {
        let widthScale = scrollView.bounds.width / imageSize.width
        let heightScale = scrollView.bounds.height / imageSize.height
        
        // Calculate the minimum scale that will fit the image
        let minScale = min(widthScale, heightScale)
        
        scrollView.minimumZoomScale = minScale
        scrollView.maximumZoomScale = max(minScale * 3.0, 2.0) // At least 2x zoom
        
        // Set initial zoom scale
        scrollView.zoomScale = minScale
        
        // Center the image
        let contentWidth = max(imageSize.width * minScale, scrollView.bounds.width)
        let contentHeight = max(imageSize.height * minScale, scrollView.bounds.height)
        
        let horizontalInset = (scrollView.bounds.width - contentWidth) / 2
        let verticalInset = (scrollView.bounds.height - contentHeight) / 2
        
        scrollView.contentInset = UIEdgeInsets(
            top: max(0, verticalInset),
            left: max(0, horizontalInset),
            bottom: max(0, verticalInset),
            right: max(0, horizontalInset)
        )
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(width: scrollView.bounds.width / 2, height: scrollView.bounds.height / 2)
            let origin = CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2)
            scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        guard let image = imageView.image else { return }
        let activityVC = UIActivityViewController(activityItems: [image, meme.title], applicationActivities: nil)
        present(activityVC, animated: true)
    }
}

extension MemeDetailViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
} 