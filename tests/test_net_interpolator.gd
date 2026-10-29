extends GutTest
## NetInterpolator: shows remote motion `delay` seconds in the past, blended between snapshots.

var net: NetInterpolator


func before_each() -> void:
	net = NetInterpolator.new()
	net.delay = 0.1


func test_empty_has_nothing_to_show() -> void:
	assert_true(net.is_empty())
	assert_false(net.sample(1.0))


func test_blends_between_snapshots_in_the_past() -> void:
	net.push(1.0, Vector3.ZERO, Quaternion.IDENTITY, 0.0)
	net.push(1.1, Vector3(1, 0, 0), Quaternion(Vector3.UP, 1.0), 0.4)
	assert_true(net.sample(1.15))  # shows t = 1.05, halfway
	assert_almost_eq(net.position.x, 0.5, 0.001)
	assert_almost_eq(net.aux, 0.2, 0.001)
	assert_almost_eq(net.rotation.get_angle(), 0.5, 0.001)
	assert_almost_eq(net.velocity.x, 10.0, 0.01)


func test_holds_the_newest_snapshot_when_data_stops() -> void:
	net.push(1.0, Vector3.ZERO, Quaternion.IDENTITY)
	net.push(1.1, Vector3(2, 0, 0), Quaternion.IDENTITY)
	net.sample(5.0)
	assert_eq(net.position, Vector3(2, 0, 0))
	assert_eq(net.velocity, Vector3.ZERO)


func test_teleport_starts_over() -> void:
	net.push(1.0, Vector3.ZERO, Quaternion.IDENTITY)
	net.push(1.05, Vector3(0.2, 0, 0), Quaternion.IDENTITY)
	net.push(1.1, Vector3(50, 0, 0), Quaternion.IDENTITY)
	net.sample(1.12)
	assert_eq(net.position, Vector3(50, 0, 0), "no sliding across the world")


func test_ignores_out_of_order_snapshots() -> void:
	net.push(1.0, Vector3(1, 0, 0), Quaternion.IDENTITY)
	net.push(0.9, Vector3(3, 0, 0), Quaternion.IDENTITY)
	net.sample(2.0)
	assert_eq(net.position, Vector3(1, 0, 0))


func test_keeps_a_bounded_buffer() -> void:
	for i: int in 50:
		net.push(i * 0.05, Vector3(i * 0.1, 0, 0), Quaternion.IDENTITY)
	net.sample(100.0)
	assert_almost_eq(net.position.x, 4.9, 0.001)
