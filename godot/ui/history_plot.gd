extends Control
## One retained native chart; no simulation updates or per-frame sampling.
var samples:Array=[]
var metric:String="population"
var range_min:float=0.
var range_max:float=1.
func _init():
 custom_minimum_size=Vector2(240,170)
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 resized.connect(queue_redraw)
func set_series(history:Array,key:String,months:int):
 metric=key;samples=[]
 var last:int=-1
 for point in history:
  if point is Dictionary and point.get("month") is int:last=maxi(last,point.month)
 for point in history:
  if not point is Dictionary or not point.get("month") is int:continue
  var value=point.get(key)
  if not(value is int or value is float) or not is_finite(float(value)):continue
  if point.month>=last-months+1:samples.append({"month":point.month,"value":float(value)})
 range_min=0.;range_max=1.
 if not samples.is_empty():
  range_min=samples[0].value;range_max=range_min
  for point in samples:range_min=minf(range_min,point.value);range_max=maxf(range_max,point.value)
  var pad:float=maxf(1.,(range_max-range_min)*.1)
  range_min-=pad;range_max+=pad
  if metric not in ["cash","net"]:range_min=maxf(0.,range_min)
 queue_redraw()
func _number(value:float)->String:
 var prefix:String=("-" if value<0 else "")+("$" if metric in ["cash","net"] else "")
 var magnitude:float=absf(value)
 var spread:float=range_max-range_min
 if magnitude>=1000000 and spread>=1000000:return prefix+"%.1fM"%(magnitude/1000000.)
 if magnitude>=1000 and spread>=1000:return prefix+"%.1fk"%(magnitude/1000.)
 return prefix+str(roundi(magnitude))
func _date(stamp:int)->String:return "%d/%02d"%[int(stamp/12),stamp%12+1]
func _draw():
 var font=ThemeDB.fallback_font
 var label_color=Color("dce7e3");var grid=Color("536a78")
 var frame=Rect2(58,12,maxf(1.,size.x-74),maxf(1.,size.y-43))
 for n in range(4):
  var y:float=frame.position.y+frame.size.y*n/3.
  draw_line(Vector2(frame.position.x,y),Vector2(frame.end.x,y),Color(grid,.45),1.)
  var value:float=lerpf(range_max,range_min,n/3.)
  draw_string(font,Vector2(0,y+4),_number(value),HORIZONTAL_ALIGNMENT_LEFT,55,11,label_color)
 if samples.is_empty():
  draw_multiline_string(font,frame.position+Vector2(12,32),"History starts with recorded city months.",HORIZONTAL_ALIGNMENT_LEFT,frame.size.x-20,12,-1,label_color)
  return
 var first:int=samples[0].month;var last:int=samples.back().month
 var points=PackedVector2Array()
 for point in samples:
  var ratio:float=float(point.month-first)/maxi(1,last-first)
  points.append(Vector2(frame.position.x+ratio*frame.size.x,frame.end.y-(point.value-range_min)/(range_max-range_min)*frame.size.y))
 if points.size()>1:draw_polyline(points,Color("8ed5b3"),2.,true)
 for point in points:
  if points.size()<=24:draw_circle(point,2.5,Color("bce8d0"))
 draw_string(font,Vector2(frame.position.x,frame.end.y+22),_date(first),HORIZONTAL_ALIGNMENT_LEFT,-1,11,label_color)
 if first!=last:draw_string(font,Vector2(frame.end.x-58,frame.end.y+22),_date(last),HORIZONTAL_ALIGNMENT_LEFT,60,11,label_color)
