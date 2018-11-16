import UIKit
import RxCocoa
import RxSwift

protocol TableViewCellDelegate: class {
    var didTapNew: AnyObserver<Link> { get }
    var didTapLast: AnyObserver<Link> { get }
}

class TableViewCell: UITableViewCell {
    
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        stackView.spacing = 8
        return stackView
    }()
    
    private let pathLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        return label
    }()
    
    private let useLastParamsButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.backgroundColor = .lightLightGray
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.layer.cornerRadius = 4
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11)
        return button
    }()
    
    private let useWithNewParamsButton: UIButton = {
        let button = UIButton(type: .roundedRect)
        button.backgroundColor = .lightLightGray
        button.setTitleColor(.black, for: .normal)
        button.setTitle("Use", for: .normal)
        button.layer.cornerRadius = 4
        return button
    }()
    
    private let disposeBag = DisposeBag()
    var link = Link() {
        didSet {
            self.didUpdateLink()
        }
    }
    weak var delegate: TableViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        contentView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            ])
        
        useLastParamsButton.translatesAutoresizingMaskIntoConstraints = false
        useWithNewParamsButton.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.addArrangedSubview(pathLabel)
        stackView.addArrangedSubview(useLastParamsButton)
        stackView.addArrangedSubview(useWithNewParamsButton)
        
        NSLayoutConstraint.activate([useLastParamsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
                                     useLastParamsButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)])
        NSLayoutConstraint.activate([useWithNewParamsButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
                                     useWithNewParamsButton.widthAnchor.constraint(equalTo: stackView.widthAnchor)])
        
        useLastParamsButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didTapLast.onNext(strongSelf.link)
        }).disposed(by: disposeBag)
        
        useWithNewParamsButton.rx.tap.subscribe(onNext: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.didTapNew.onNext(strongSelf.link)
        }).disposed(by: disposeBag)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func didUpdateLink() {
        pathLabel.text = link.path
        
        if let lastUse = link.uses.last {
            useLastParamsButton.setTitle("Use Last - \(lastUse.parameters.map { "\($0.key): \($0.value)" }.joined(separator: ", "))", for: .normal)
            useLastParamsButton.isHidden = false
            useLastParamsButton.sizeToFit()
        } else {
            useLastParamsButton.isHidden = true
        }
    }
    
}


extension UIColor {
    
    fileprivate static var lightLightGray: UIColor {
        return UIColor(red: 0, green: 0, blue: 0, alpha: 0.15)
    }
    
}
