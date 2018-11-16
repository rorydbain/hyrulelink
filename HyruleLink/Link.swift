import RealmSwift
import RxSwift

class LinkParam: Object {
    @objc dynamic var key = ""
    @objc dynamic var value = ""
}

class History: Object {
    @objc dynamic var timestamp = Date()
    @objc dynamic var parameterisedPath = ""
    var parameters = List<LinkParam>()
}

class Link: Object {
    @objc dynamic var path = ""
    @objc dynamic var dateAdded = Date()
    @objc dynamic var lastUse = Date()
    let uses = List<History>()
    
    static var all: Results<Link> {
        let descriptors: [SortDescriptor] = [SortDescriptor(keyPath: "lastUse", ascending: false),
                                             SortDescriptor(keyPath: "dateAdded", ascending: false)]
        
        return try! Realm()
            .objects(self)
            .sorted(by: descriptors)
        
    }
    
    static func didUse(link: Link, withParams params: [String: String]?, fullPath: String) {
        let realm = try! Realm()
        try! realm.write {
            let use = History()
            use.parameterisedPath = fullPath
            link.lastUse = Date()
            if let params = params {
                params.forEach { (key, value) in
                    let lp = LinkParam()
                    lp.key = key
                    lp.value = value
                    use.parameters.append(lp)
                }
            }
            link.uses.append(use)
        }
    }
    
    static func didUseLast(link: Link, use: History) {
        let realm = try! Realm()
        try! realm.write {
            link.lastUse = Date()
            if let existing = link.uses.index(of: use) {
                link.uses.remove(at: existing)
                link.uses.append(use)
            }
        }
    }
    
}
