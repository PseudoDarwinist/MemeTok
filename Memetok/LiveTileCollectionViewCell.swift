import UIKit

class LiveTileCollectionViewCell: UICollectionViewCell {
    static let identifier = "LiveTileCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerRadius = 4
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        return label
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private let countLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private var animator: UIViewPropertyAnimator?
    private var isAnimating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.addSubview(containerView)
        containerView.addSubview(iconImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(countLabel)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            countLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            countLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12)
        ])
    }
    
    func configure(with subcategory: MemeSubcategory, count: Int, color: UIColor) {
        titleLabel.text = subcategory.name
        countLabel.text = "\(count)"
        containerView.backgroundColor = color
        
        // Set icon based on category
        let iconName: String
        if subcategory.id.contains("ai") {
            iconName = "cpu"
        } else if subcategory.id.contains("gaming") {
            iconName = "gamecontroller"
        } else if subcategory.id.contains("cricket") {
            iconName = "figure.cricket"
        } else if subcategory.id.contains("soccer") {
            iconName = "figure.soccer"
        } else if subcategory.id.contains("hollywood") {
            iconName = "film"
        } else if subcategory.id.contains("bollywood") {
            iconName = "film.fill"
        } else if subcategory.id.contains("elon") {
            iconName = "person.fill"
        } else if subcategory.id.contains("cloud") {
            iconName = "cloud.fill"
        } else if subcategory.id.contains("programming") {
            iconName = "chevron.left.forwardslash.chevron.right"
        } else if subcategory.id.contains("apple") {
            iconName = "apple.logo"
        } else if subcategory.id.contains("anime") {
            iconName = "play.tv"
        } else if subcategory.id.contains("streaming") {
            iconName = "play.circle"
        } else if subcategory.id.contains("politics") {
            iconName = "building.columns"
        } else if subcategory.id.contains("elections") {
            iconName = "checkmark.circle"
        } else {
            iconName = "square.grid.2x2"
        }
        
        iconImageView.image = UIImage(systemName: iconName)
        
        startAnimation()
    }
    
    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        
        let animation = UIViewPropertyAnimator(duration: 2.0, dampingRatio: 0.7) {
            self.containerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
        
        animation.addCompletion { _ in
            UIView.animate(withDuration: 2.0, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.1, options: [.repeat, .autoreverse], animations: {
                self.containerView.transform = .identity
            })
        }
        
        animation.startAnimation()
        self.animator = animation
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        animator?.stopAnimation(true)
        containerView.transform = .identity
        isAnimating = false
        titleLabel.text = nil
        countLabel.text = nil
        iconImageView.image = nil
    }
} 