import CoreGraphics

//Useful?

public enum JCSAPlacement {
	case leading
	case center
	case trailing
}

struct Position: Hashable, Identifiable {
	let x: Int
	let y: Int
	let z: Int

	init(x: Int = 0, y: Int = 0, z: Int = 0) {
		self.x = x
		self.y = y
		self.z = z
	}

	var id: Self { self }
}
