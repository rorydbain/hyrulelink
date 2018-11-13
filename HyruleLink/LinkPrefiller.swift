import RealmSwift
import Foundation

struct LinkPrefiller {
    
    static func prefillLinks() {
        DispatchQueue.main.async {
            guard let path = Bundle.main.path(forResource: "deeplinks", ofType: "txt"),
                let data = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            
            let paths = data.components(separatedBy: .newlines)
            let realm = try! Realm()
            
            paths
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .forEach { path in
                    guard realm
                        .objects(Link.self)
                        .filter(NSPredicate(format: "path = %@", path))
                        .first == nil else { return }
                    
                    try! realm.write {
                        let link = Link()
                        link.path = path
                        realm.add(link)
                    }
            }
            
        }
        
    }
    
}
