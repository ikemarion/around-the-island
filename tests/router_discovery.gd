extends SceneTree
func _initialize() -> void:
	var router := UPNP.new()
	var result := router.discover(2000,2,"InternetGatewayDevice")
	print("ROUTER_DISCOVERY result=",result," devices=",router.get_device_count()," valid_gateway=",router.get_gateway()!=null and router.get_gateway().is_valid_gateway())
	quit()
