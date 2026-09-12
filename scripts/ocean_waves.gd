extends RefCounted
# Direction X/Z, amplitude in metres, wavelength in metres. Shared with the GPU.
const WAVES=[Vector4(.94,.34,.65,62),Vector4(.78,-.63,.32,37),Vector4(.43,.90,.16,23),Vector4(-.25,.97,.08,14)]

static func shore_distance(p: Vector2,centers: PackedVector2Array,radius: float) -> float:
	var distance=10000.0
	for center in centers:
		var q=p-center
		distance=minf(distance,maxf(absf(q.x),maxf(absf(q.x*.5+q.y*.8660254),absf(-q.x*.5+q.y*.8660254)))-radius*.8660254)
	return distance

static func displacement(p: Vector2,time: float,storm: float,quality: int,centers: PackedVector2Array,radius: float) -> Vector3:
	var result=Vector3.ZERO
	var shore=smoothstep(2.0,22.0,shore_distance(p,centers,radius))*(1.0-smoothstep(350.0,650.0,maxf(absf(p.x),absf(p.y))))
	var spacing=900.0/[65.0,129.0,225.0,321.0][quality]
	for wave in WAVES:
		var direction=Vector2(wave.x,wave.y).normalized()
		var k=TAU/wave.w
		var phase=k*direction.dot(p)-sqrt(9.81*k)*time
		var amplitude=wave.z*(1.0+storm*1.8)*shore*smoothstep(spacing*2.0,spacing*5.0,wave.w)
		result+=Vector3(direction.x*cos(phase)*.7,sin(phase),direction.y*cos(phase)*.7)*amplitude
	return result

static func height(p: Vector2,time: float,storm: float,quality: int,centers: PackedVector2Array,radius: float) -> float:
	# Invert the small horizontal Gerstner displacement so boats sample world positions.
	var origin=p
	for i in 3:
		var offset=displacement(origin,time,storm,quality,centers,radius)
		origin=p-Vector2(offset.x,offset.z)
	return displacement(origin,time,storm,quality,centers,radius).y
