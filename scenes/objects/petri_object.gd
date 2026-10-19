class_name PetriObject

var _body : RID
var _visual : RID
var _shape : RID

func _init(body, visual, shape):
	_body = body
	_visual = visual
	_shape = shape

func get_body():
	return _body

func get_canvas_item():
	return _visual

func get_shape():
	return _shape

func sync_visual(radius : float) -> void:
	var t : Transform2D = get_transform()
	t = t.scaled_local(Vector2(radius * 2.0, radius * 2.0))   # unit rect has diameter 1
	RenderingServer.canvas_item_set_transform(_visual, t)

func destroy() -> void:
	PhysicsServer2D.free_rid(_body)
	PhysicsServer2D.free_rid(_shape)
	RenderingServer.free_rid(_visual)

func get_transform() -> Transform2D:
	return PhysicsServer2D.body_get_state(_body, PhysicsServer2D.BODY_STATE_TRANSFORM)
