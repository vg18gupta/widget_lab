import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/presentation/grid_painter.dart';
import 'package:widget_lab/presentation/panel_card.dart';
import 'package:widget_lab/theme/palette.dart';

/// The whole screen: top bar, widget hub, canvas and dev strip. It draws the layout held by
/// the store and sends actions to the controllers.
class LabHome extends StatefulWidget {
  const LabHome({super.key,required this.app});
  final AppControllers app;
  @override State<LabHome> createState()=>_LabHomeState();
}

class _LabHomeState extends State<LabHome> {
  /// Marks the grid's content box, to convert drop positions into cells.
  final GlobalKey _gridKey = GlobalKey();
  /// Ghost outline showing where a widget dragged from the hub will land.
  final ValueNotifier<Panel?> _shadow = ValueNotifier<Panel?>(null);

  /// Seed field in the dev strip. Starts at the market's current seed.
  late final TextEditingController _seedCtrl = TextEditingController(text:'${widget.app.market.seed}');

  @override void dispose() { _shadow.dispose(); _seedCtrl.dispose(); super.dispose(); }

  /// Restarts the live feed's random walk with the seed in the field. History is kept.
  void _applySeed() {
    final n=int.tryParse(_seedCtrl.text.trim());
    if(n==null) {
      _seedCtrl.text='${widget.app.market.seed}';
      return;
    }
    setState(()=>widget.app.market.configure(newSeed:n));
  }

  @override Widget build(BuildContext context) => Shortcuts(
    shortcuts: {
      LogicalKeySet(LogicalKeyboardKey.control,LogicalKeyboardKey.keyZ):const UndoIntent(),
      LogicalKeySet(LogicalKeyboardKey.meta,LogicalKeyboardKey.keyZ):const UndoIntent(),
    },
    child:Actions(actions:{UndoIntent:CallbackAction<UndoIntent>(onInvoke:(_){widget.app.layout.undo();return null;})},
      child:Scaffold(body:SafeArea(child:Column(children:[
        _topBar(),
        Expanded(child:LayoutBuilder(builder:(context,c){
          final narrow=c.maxWidth<900;
          return Row(children:[
            if(!narrow) SizedBox(width:190,child:_hub()),
            Expanded(child:_workspace(narrow,c.maxWidth)),
          ]);
        })),
        _devPanel(),
      ])))));

  Widget _topBar()=>Container(height:58,padding:const EdgeInsets.symmetric(horizontal:18),
    decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Palette.border))),
    child:Row(children:[
      const Icon(Icons.dashboard_customize,color:Palette.accent),const SizedBox(width:10),
      const SizedBox(width:8),const Text('WIDGET LAB',style:TextStyle(color:Palette.textMuted,fontSize:12)),
      const Spacer(),
      AnimatedBuilder(animation:widget.app.store,builder:(_,__)=>IconButton(
        tooltip:widget.app.store.locked?'Unlock layout':'Lock layout',
        onPressed:()=>widget.app.layout.setLocked(!widget.app.store.locked),
        icon:Icon(widget.app.store.locked?Icons.lock:Icons.lock_open))),
      IconButton(tooltip:'Undo (Ctrl+Z)',onPressed:widget.app.layout.undo,icon:const Icon(Icons.undo)),
      TextButton(onPressed:()=>setState(()=>widget.app.layout.reset()),child:const Text('Reset layout')),
    ]));

  Widget _hub()=>Container(color:Palette.surface,padding:const EdgeInsets.all(14),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('WIDGET HUB',style:TextStyle(fontSize:11,color:Palette.textMuted,fontWeight:FontWeight.bold)),
      const SizedBox(height:14),
      AnimatedBuilder(animation:widget.app.store,builder:(_,__)=>Column(mainAxisSize:MainAxisSize.min,children:[
        for(final k in WidgetKind.values) Padding(padding:const EdgeInsets.only(bottom:9),
          child:Draggable<WidgetKind>(data:k,maxSimultaneousDrags:widget.app.store.locked?0:null,
            feedback:Material(color:Colors.transparent,child:_hubTile(k)),
            child:_hubTile(k))),
      ])),
      const Spacer(),const Text('Drag a widget onto the canvas',style:TextStyle(fontSize:11,color:Palette.textFaint)),
    ]));
  Widget _hubTile(WidgetKind k)=>Container(padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Palette.tile,borderRadius:BorderRadius.circular(9)),
    child:Row(children:[Icon(_kindIcon(k),size:17),const SizedBox(width:9),Text(_kindName(k))]));
  IconData _kindIcon(WidgetKind k)=>switch(k){WidgetKind.chart=>Icons.show_chart,WidgetKind.table=>Icons.table_chart,WidgetKind.script=>Icons.code};
  String _kindName(WidgetKind k)=>switch(k){WidgetKind.chart=>'Chart',WidgetKind.table=>'Table',WidgetKind.script=>'Script'};

  /// The cell a widget dragged from the hub would land in, with its top-left corner
  /// at the global position [global]. Null when the grid isn't on screen.
  Panel? _dropSlot(Offset global, WidgetKind kind, double cellW) {
    final box=_gridKey.currentContext?.findRenderObject() as RenderBox?;
    if(box==null) return null;
    final local=box.globalToLocal(global);
    final w=kind.defaultW, h=kind.defaultH;
    final x=min(max((local.dx/cellW).round(),0),gridColumns-w);
    final y=max((local.dy/rowHeight).round(),0);
    return Panel(id:'shadow',kind:kind,x:x,y:y,w:w,h:h);
  }

  Widget _workspace(bool narrow,double width){
    final cellW=(width-42)/gridColumns;
    return DragTarget<WidgetKind>(
      onMove:(d){
        if(narrow||widget.app.store.locked) return;
        final slot=_dropSlot(d.offset,d.data,cellW);
        final cur=_shadow.value;
        if(slot==null||cur==null||cur.x!=slot.x||cur.y!=slot.y) _shadow.value=slot;
      },
      onLeave:(_)=>_shadow.value=null,
      onAcceptWithDetails:(d){
        if(widget.app.store.locked) {
          _shadow.value=null;
          return;
        }
        final slot=narrow?null:_dropSlot(d.offset,d.data,cellW);
        _shadow.value=null;
        if(slot==null) {
          widget.app.layout.add(d.data);
        } else {
          widget.app.layout.addAt(d.data,slot.x,slot.y);
        }
      },
      builder:(context,candidates,rejected)=>Container(
        margin:const EdgeInsets.all(12),padding:const EdgeInsets.all(10),
        decoration:BoxDecoration(color:Palette.canvas,borderRadius:BorderRadius.circular(12),
          border:Border.all(color:candidates.isNotEmpty?Palette.accent:Palette.border,width:1.2)),
        child:AnimatedBuilder(animation:widget.app.store,builder:(context,_){
          final store=widget.app.store;
          if(!store.loaded) return const Center(child:CircularProgressIndicator());
          final full=store.fullscreenPanel;
          if(full!=null) return PanelCard(key:ValueKey('fullscreen-${full.id}'),panel:full,
            app:widget.app,cellW:cellW,interactive:false);
          if(store.panels.isEmpty) return _emptyCanvas();
          if(narrow) return ListView(children:[
            if(width<900) Padding(padding:const EdgeInsets.only(bottom:10),child:_addChips()),
            for(final p in store.panels) Padding(padding:const EdgeInsets.only(bottom:12),
              child:SizedBox(height:330,child:PanelCard(panel:p,app:widget.app,
                cellW:0,interactive:false)))
          ]);
          final maxY=store.panels.fold<int>(12,(v,p)=>max(v,p.y+p.h+1));
          return SingleChildScrollView(child:SizedBox(key:_gridKey,height:maxY*rowHeight,width:double.infinity,
            child:Stack(children:[
              Positioned.fill(child:CustomPaint(painter:GridPainter(cellW))),
              for(final p in store.panels)
                Positioned(left:p.x*cellW,top:p.y*rowHeight,width:p.w*cellW-5,height:p.h*rowHeight-5,
                  child:PanelCard(key:ValueKey(p.id),panel:p,app:widget.app,
                    cellW:cellW,interactive:!store.locked)),
              Positioned.fill(child:IgnorePointer(child:ValueListenableBuilder<Panel?>(
                valueListenable:_shadow,
                builder:(_,s,__)=>Stack(children:[
                  if(s!=null) Positioned(left:s.x*cellW,top:s.y*rowHeight,width:s.w*cellW-5,height:s.h*rowHeight-5,
                    child:DecoratedBox(decoration:BoxDecoration(color:Palette.accentSoft,
                      borderRadius:BorderRadius.circular(10),
                      border:Border.all(color:Palette.accentStrong,width:1.5)))),
                ])))),
            ])));
        }),
      ),
    );
  }

  Widget _addChips()=>Wrap(spacing:8,runSpacing:8,children:
    WidgetKind.values.map((k)=>ActionChip(label:Text('+ ${_kindName(k)}'),
      onPressed:widget.app.store.locked?null:()=>widget.app.layout.add(k))).toList());
  Widget _emptyCanvas()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Icon(Icons.dashboard_customize_outlined,size:36,color:Palette.textFaint),
    const SizedBox(height:10),
    const Text('No widgets on the canvas',style:TextStyle(color:Palette.textSecondary)),
    const SizedBox(height:4),
    const Text('Drag a widget from the hub, or add one:',style:TextStyle(fontSize:11,color:Palette.textFaint)),
    const SizedBox(height:12),
    _addChips(),
  ]));

  Widget _devPanel()=>Container(height:54,padding:const EdgeInsets.symmetric(horizontal:16),
    decoration:const BoxDecoration(border:Border(top:BorderSide(color:Palette.border))),
    child:Row(children:[
      const Icon(Icons.developer_mode,size:16,color:Palette.textMuted),const SizedBox(width:8),
      const Text('DEV FEED',style:TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Palette.textMuted)),
      const SizedBox(width:12),
      TextButton(onPressed:()=>setState(()=>widget.app.market.configure(pause:!widget.app.market.paused)),
        child:Text(widget.app.market.paused?'Resume':'Pause')),
      TextButton(onPressed:()=>setState(()=>widget.app.market.configure(drop:!widget.app.market.dropped)),
        child:Text(widget.app.market.dropped?'Reconnect':'Drop feed')),
      const Text('Seed',style:TextStyle(fontSize:11,color:Palette.textMuted)),const SizedBox(width:6),
      SizedBox(width:70,child:TextField(controller:_seedCtrl,keyboardType:TextInputType.number,
        style:const TextStyle(fontSize:12),onSubmitted:(_)=>_applySeed(),
        decoration:const InputDecoration(isDense:true,border:OutlineInputBorder()))),
      TextButton(onPressed:_applySeed,child:const Text('Apply')),
      const Spacer(),const Text('Rate',style:TextStyle(fontSize:11,color:Palette.textMuted)),
      SizedBox(width:115,child:Slider(min:100,max:200,divisions:2,value:widget.app.market.intervalMs.toDouble(),
        onChanged:(v)=>setState(()=>widget.app.market.configure(rate:v.round())))),
      Text('${widget.app.market.intervalMs}ms',style:const TextStyle(fontSize:11)),
    ]));
}

class UndoIntent extends Intent { const UndoIntent(); }
