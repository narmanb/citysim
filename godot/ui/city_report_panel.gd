extends VBoxContainer
## Data-only presentation. All changes to the city go through explicit signals.
signal overlay_requested(key:String)
signal challenge_start_requested(id:String)
signal challenge_abandon_requested
const Plot=preload("res://ui/history_plot.gd")
const OVERLAY_TITLES={"school":"education coverage","hospital":"health coverage","traffic":"traffic","power":"power supply","water":"water supply","crime":"crime","pollution":"pollution"}
const METRICS={"population":"Population","jobs":"Jobs","cash":"Treasury","net":"Monthly budget","crime":"Resident crime (0–100)","pollution":"Resident pollution (0–100)","traffic":"Traffic (%)","approval":"Approval (%)"}
var _report:Dictionary={}
var _points:Array=[]
var _definitions:Array=[]
var _active:Dictionary={}
var _section:String="Overview"
var _metric:String="population"
var _window:int=12
var _body:VBoxContainer
var _buttons:Dictionary={}
func _ready():
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 add_theme_constant_override("separation",10)
 var tabs=HBoxContainer.new();tabs.add_theme_constant_override("separation",4);add_child(tabs)
 for section in ["Overview","Growth","History","Challenges"]:
  var b=Button.new();b.text=section;b.toggle_mode=true;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  b.pressed.connect(func():select_section(section));tabs.add_child(b);_buttons[section]=b
 _body=VBoxContainer.new();_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_body.add_theme_constant_override("separation",8);add_child(_body)
 _render()
func present(report:Dictionary,history:Array,definitions:Array,active:Dictionary):
 _report=report.duplicate(true);_points=history.duplicate(true);_definitions=definitions.duplicate(true);_active=active.duplicate(true)
 if is_node_ready():_render()
func select_section(section:String):
 if section not in ["Overview","Growth","History","Challenges"]:return
 _section=section;_render()
func _text(text:String,node_name:String="")->Label:
 var label=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if not node_name.is_empty():label.name=node_name
 _body.add_child(label);return label
func _button(text:String,node_name:String,callback:Callable)->Button:
 var b=Button.new();b.text=text;b.name=node_name;b.size_flags_horizontal=Control.SIZE_EXPAND_FILL;b.custom_minimum_size.y=36
 b.pressed.connect(callback);_body.add_child(b);return b
func _render():
 if _body==null:return
 for child in _body.get_children():_body.remove_child(child);child.queue_free()
 for key in _buttons:_buttons[key].button_pressed=key==_section
 match _section:
  "Overview":_overview()
  "Growth":_growth()
  "History":_history()
  "Challenges":_challenges()
func _overview():
 _text("Approval: %d%% — %s"%[int(_report.get("approval",50)),str(_report.get("headline","Start a neighborhood"))],"Approval").add_theme_font_size_override("font_size",18)
 var s:Dictionary=_report.get("summary",{})
 _text("Residents %s · Jobs %s · Unemployment %s%%\nTraffic %s%% · Unserved commuters %s · Average route %.1f tiles\nMonthly budget %s$%s"%[s.get("population",0),s.get("jobs",0),s.get("unemployment",0),s.get("congestion",0),s.get("commuteUnserved",0),float(s.get("avgCommute",0)),"+" if float(s.get("net",0))>=0 else "",s.get("net",0)])
 var issues:Array=_report.get("issues",[])
 if issues.is_empty():_text("No urgent concerns. Keep an eye on city growth and finances.")
 for issue in issues.slice(0,5):
  _text(str(issue.get("title","City concern"))).add_theme_color_override("font_color",Color("ffba91") if float(issue.get("severity",0))>=70 else Color("f1d58c"))
  _text(str(issue.get("description","")))
  var overlay:String=str(issue.get("overlay",""))
  if not overlay.is_empty():_button("Show "+str(OVERLAY_TITLES.get(overlay,overlay))+" on map","Overlay_"+str(issue.get("id",overlay)),func():overlay_requested.emit(overlay))
func _growth():
 _text(str(_report.get("growthTitle","Select a property"))).add_theme_font_size_override("font_size",18)
 for reason in _report.get("growth",["Select a zoned tile with Pan, then reopen Report to inspect its growth."]):_text("• "+str(reason))
func _history():
 var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",8);_body.add_child(controls)
 var choice=OptionButton.new();choice.name="HistoryMetric";choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL;controls.add_child(choice)
 var keys:Array=METRICS.keys()
 for key in keys:choice.add_item(METRICS[key])
 choice.select(maxi(0,keys.find(_metric)));choice.item_selected.connect(func(i):_metric=keys[i];_render())
 var span=OptionButton.new();span.name="HistoryWindow";controls.add_child(span)
 for value in ["12 months","5 years","20 years"]:span.add_item(value)
 var windows:Array=[12,60,240]
 span.select(maxi(0,windows.find(_window)));span.item_selected.connect(func(i):_window=windows[i];_render())
 var plot=Plot.new();plot.name="HistoryPlot";_body.add_child(plot);plot.set_series(_points,_metric,_window)
 _text("One point per simulated month. Earlier history is unavailable for imported cities.")
func _challenges():
 if not _active.is_empty():
  var status:String=str(_active.get("status","active"))
  var title:String=str(_active.get("id","Challenge"))
  for definition in _definitions:
   if definition.id==_active.get("id"):title=definition.title
  _text(title+" — "+status.capitalize()).add_theme_font_size_override("font_size",18)
  _text("Month %d / %d · Goals held %d / 3 months"%[int(_active.get("elapsed",0)),int(_active.get("duration",0)),int(_active.get("streak",0))])
  for line in _active.get("progress",[]):_text(str(line))
  if status=="active":_button("Abandon challenge","AbandonChallenge",func():challenge_abandon_requested.emit())
  else:_text("Your city remains playable. You may start another challenge.")
 else:_text("Sandbox mode — optional challenges use this city and do not replace the map.")
 for definition in _definitions:
  _text(str(definition.title)).add_theme_font_size_override("font_size",16)
  _text(str(definition.description)+"\n%d months; meet all goals for 3 consecutive months."%int(definition.duration))
  var id:String=str(definition.id)
  var b=_button("Start "+str(definition.title),"Start_"+id,func():challenge_start_requested.emit(id))
  b.disabled=_active.get("status","")=="active" or not bool(definition.get("available",true))
  if not bool(definition.get("available",true)):_text("Requires at least 100 residents.")
