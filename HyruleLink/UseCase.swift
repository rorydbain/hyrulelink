import RxRealm
import RealmSwift
import RxSwift

struct UseCase {
    
    struct Inputs {
        let newPathName: Observable<String>
        let didTapUseLast: Observable<Link>
        let didTapUseNew: Observable<Link>
    }
    
    struct Outputs {
        let showError: Observable<OkAlert>
    }
    
    static func makeStreams(inputs: Inputs, viewController: UIViewController?, disposeBag: DisposeBag) -> Outputs {
        
        let showError = PublishSubject<OkAlert>()
        
        inputs
            .newPathName
            .map { path in
                let link = Link()
                link.path = path
                return link
            }
            .bind(to: Realm.rx.add(onError: { elements, error in
                if let elements = elements {
                    showError.onNext(.init(title: "Failed to add", message: "Error \(error.localizedDescription) while saving objects \(String(describing: elements))"))
                } else {
                    showError.onNext(.init(title: "Failed to add", message: "Error \(error.localizedDescription) while opening realm."))
                }
            }))
            .disposed(by: disposeBag)
        
        
        let baseUrl = "https://www.fanduel.com"
        let newPathToOpen = inputs
            .didTapUseNew
            .flatMap { link in link.populateParameters(presentingAlertFrom: viewController)
                .map { params -> String in
                    if URL(string: [baseUrl, params.fullPath].joined()) != nil {
                        Link.didUse(link: link, withParams: params.replacements, fullPath: params.fullPath)
                    }
                    return params.fullPath
                }
            }
        
        let alreadyUsedPathToOpen = inputs
            .didTapUseLast
            .flatMap { link -> Observable<String> in
                guard let lastUse = link.uses.last else { return Observable.empty() }
                Link.didUseLast(link: link, use: lastUse)
                return Observable.just(lastUse.parameterisedPath)
        }
        
        Observable.merge(newPathToOpen, alreadyUsedPathToOpen)
            .subscribe(onNext: { path in
                let urlString = [baseUrl, path].joined()
                guard let url = URL(string: urlString) else {
                    showError.onNext(.init(title: "Failed to make url", message: "Could not make url with text '\(urlString)'"))
                    return
                }
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            })
            .disposed(by: disposeBag)
        
        return Outputs(showError: showError.asObservable())
    }
    
}


//func didTapUseNew(link: Link) {
//    link.populateParameters(presentingAlertFrom: self) { [weak self] linkInfo in
//        self?.open(path: linkInfo.fullPath, completion: {
//            link.didUse(withParams: linkInfo.replacements, fullPath: linkInfo.fullPath)
//        })
//    }
//}
//
//func didTapUseLast(link: Link) {
//    self.open(path: link.lastBuiltPath) {
//        link.didUse(withParams: nil, fullPath: link.lastBuiltPath)
//    }
//}
//
//private func open(path: String, completion: @escaping () -> Void) {
//    let urlString = "https://www.fanduel.com\(path)"
//    if let url = URL(string: urlString) {
//        UIApplication.shared.open(url, options: [:], completionHandler: { _ in
//            completion()
//        })
//    } else {
//        //            showError(title: "Failed to make url", message: "Could not make url with text '\(urlString)'")
//    }
//}
