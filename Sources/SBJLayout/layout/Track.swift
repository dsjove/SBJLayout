import CoreGraphics

public struct Track {
	public enum AccessoryPlacement: Equatable {
		case before
		case after
	}

	public enum Role: Equatable {
		case normal
		case accessory(AccessoryPlacement)

		public var isAccessory: Bool {
			if case .accessory = self { return true }
			return false
		}

		public var accessoryPlacement: AccessoryPlacement? {
			if case let .accessory(placement) = self { return placement }
			return nil
		}
	}

	public let role: Role
	public typealias Aggregate = ([CGFloat]) -> CGFloat?

	public let length: TrackSize
	public let align: Alignment
	public let gap: CGFloat
	public let aggregate: Aggregate

	public init(
		_ length: TrackSize = .intrinsic(),
		align: Alignment = .left, //Column centric
		gap: CGFloat = 3.0,
		aggregate: @escaping Aggregate = { $0.max() },
		role: Role = .normal
	) {
		self.role = role
		self.length = length
		self.align = align
		self.gap = gap
		self.aggregate = aggregate
	}

	public init(
		_ track: Track,
		aggregate: @escaping Aggregate
	) {
		self.init(
			track.length,
			align: track.align,
			gap: track.gap,
			aggregate: aggregate,
			role: track.role
		)
	}
	public static func rowAccessory(
		placement: AccessoryPlacement = .after,
		gap: CGFloat = 0,
		align: Alignment = .leftTop
	) -> Self {
		.init(.intrinsic(), align: align, gap: gap, role: .accessory(placement))
	}
}
