import Foundation
import CoreGraphics
import UIKit

public enum ImageSource: Sendable {
	case none
	case bundled(String, Bundle? = nil)
	case system(String)
	case file(URL)

	public var isEmpty: Bool {
		switch self {
		case .none:
			true
		case .bundled(let name, _):
			name.isEmpty
		case .system(let name):
			name.isEmpty
		case .file(let url):
			url.path.isEmpty
		}
	}

	public var image: UIImage? {
		switch self {
		case .none:
			return nil
		case .bundled(let name, let bundle):
			return UIImage(named: name, in: bundle, compatibleWith: nil)
		case .system(let name):
			return UIImage(systemName: name)
		case .file(let url):
			let didAccess = url.startAccessingSecurityScopedResource()
			defer {
				if didAccess { url.stopAccessingSecurityScopedResource() }
			}
			return UIImage(contentsOfFile: url.path)
		}
	}

	public var data: Data? {
		self.image?.pngData()
	}
}
