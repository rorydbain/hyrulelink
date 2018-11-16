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
    
    static func makeStreams(inputs: Inputs, viewController: ViewControllerPresenting?, disposeBag: DisposeBag) -> Outputs {
        
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
            .flatMap { link in UseCase.populateParameters(for: link, presentingAlertFrom: viewController)
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
    
    // weird but hey ho
    static func populateParameters(for link: Link, presentingAlertFrom viewController: ViewControllerPresenting?) -> Observable<LinkInfo> {
        let paramRegex = "\\$\\{(.*?)\\}" // e.g. /pickem/${tournamentId}
        let matches = try! NSRegularExpression(pattern: paramRegex)
            .matches(in: link.path, options: [], range: NSRange(link.path.startIndex..., in: link.path))
        
        return Observable
            .from(matches)
            .concatMap { match -> Observable<(RegexReplacement)> in
                let path = link.path
                guard
                    let vc = viewController,
                    let swiftRange = Range(match.range, in: path) else { return Observable.empty() }
                
                return vc
                    .show(textFieldAlertViewModel: .init(title: "Enter value for \(String(path[swiftRange]))", message: nil))
                    .map { textInput in RegexReplacement(checkingResult: match, replacement: textInput) }
            }
            .toArray()
            .map({ matches in self.replaceChunks(for: link, matchesToUserInput: matches) })
    }
    
    static private func replaceChunks(for link: Link, matchesToUserInput: [RegexReplacement]) -> LinkInfo {
        let path = link.path
        guard !matchesToUserInput.isEmpty else { return LinkInfo(fullPath: path, replacements: [:]) }
        
        var output = ""
        var previousMatch: NSTextCheckingResult?
        var replacements = [String: String]()
        for (i, regexReplacement) in matchesToUserInput.enumerated() {
            let (match, replacement) = (regexReplacement.checkingResult, regexReplacement.replacement)
            let currentMatchRange = Range(match.range, in: path)!
            
            if let previousMatch = previousMatch {
                let previousMatchRange = Range(previousMatch.range, in: path)!
                let chunk = path[previousMatchRange.upperBound..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            } else {
                let chunk = path[path.startIndex..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            }
            
            let currentKey = String(path[Range(match.range, in: path)!])
            replacements[currentKey] = replacement
            output.append(replacement)
            
            if i == matchesToUserInput.count - 1 {
                let chunk = path[currentMatchRange.upperBound...]
                output.append(String(chunk))
            }
            
            previousMatch = match
        }
        
        return LinkInfo(fullPath: output, replacements: replacements)
    }
    
}

struct LinkInfo {
    let fullPath: String
    let replacements: [String: String]
}

struct RegexReplacement {
    let checkingResult: NSTextCheckingResult
    let replacement: String
}
