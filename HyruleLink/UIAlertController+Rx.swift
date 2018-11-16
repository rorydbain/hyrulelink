import RxSwift
import UIKit

protocol ViewControllerPresenting: class {
    func present(viewController: UIViewController)
}

struct TextFieldAlertViewModel {
    let title: String?
    let message: String?
}


extension ViewControllerPresenting {

    
    func show(textFieldAlertViewModel: TextFieldAlertViewModel) -> Observable<String> {
        return Observable.create { [weak self] observer in
            let alert = UIAlertController(title: textFieldAlertViewModel.title,
                                          message: textFieldAlertViewModel.message,
                                          preferredStyle: .alert)
            
            alert.addAction(.init(title: "Cancel",
                                  style: .cancel,
                                  handler: { _ in
                                    observer.onCompleted() }))
            
            alert.addAction(.init(title: "Submit",
                                  style: .default,
                                  handler: { _ in
                                    observer.onNext(alert.textFields?.first?.text ?? "")
                                    observer.onCompleted() }))
            
            alert.addTextField(configurationHandler: { _ in })
            
            self?.present(viewController: alert)
            
            return Disposables.create {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

