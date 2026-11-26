import 'package:widget_lab/theme/palette.dart';
import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/constants.dart';
import 'package:widget_lab/models/panel.dart';
import 'package:widget_lab/models/tick.dart';
import 'package:widget_lab/script/script_runner.dart';
import 'package:widget_lab/state/workspace.dart';
import 'package:widget_lab/ui/frame_budget.dart';
import 'package:widget_lab/ui/widget_error.dart';

/// Build counts per part of the panel, for performance tests. Not used by the UI.
@visibleForTesting
final Map<String,int> panelBuildCounts = {};
void _count(String part) => panelBuildCounts[part] = (panelBuildCounts[part] ?? 0) + 1;

String _clock(DateTime t) =>
  '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:${t.second.toString().padLeft(2,'0')}';

class PanelCard extends StatefulWidget {
  const PanelCard({super.key,required this.panel,required this.workspace,required this.market,
    required this.cellW,required this.interactive});
  final Panel panel; final Workspace workspace; final MarketStore market;
  /// Current column width in pixels, used to convert drag distance into grid cells.
  final double cellW;
  /// False when the card is shown outside the grid (narrow layout, full screen), where drag and resize are disabled.
  final bool interactive;
  @override State<PanelCard> createState()=>_PanelCardState();
}
class _PanelCardState extends State<PanelCard> {
  Timer? _saveTimer;
  Offset _gestureTotal = Offset.zero;
  String? error;
  late final TextEditingController _editor;
  final FocusNode _editorFocus = FocusNode();
  Map<String, dynamic>? _scriptResult;
  final List<String> _console = [];

  void _startGesture() {
    _gestureTotal = Offset.zero;
    widget.workspace.beginGesture(widget.panel);
  }
  void _log(String msg) {
    _console.add('${_clock(DateTime.now())} $msg');
    if (_console.length > 50) _console.removeAt(0);
  }
  @override void initState() {
    super.initState();
    _editor = TextEditingController(text: widget.panel.code);
  }
  @override void didUpdateWidget(covariant PanelCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.panel.code != widget.panel.code && !_editorFocus.hasFocus) {
      _editor.value = TextEditingValue(
        text: widget.panel.code,
        selection: TextSelection.collapsed(offset: widget.panel.code.length),
      );
    }
  }
  @override void dispose(){
    _saveTimer?.cancel();_trailing?.cancel();_redraw.dispose();
    _editor.dispose();_editorFocus.dispose();super.dispose();
  }

  // ---- Optional redraw cap (see chartRedrawInterval) ---------------------------
  /// Bumped when a skipped redraw is due, so the chart draws the latest data.
  final ValueNotifier<int> _redraw = ValueNotifier<int>(0);
  Timer? _trailing;
  bool _dueRedraw=false;
  DateTime? _lastDraw;
  Widget? _lastChart;
  String? _lastKey;

  /// Draws the chart, or reuses the last drawing if the interval since the last draw has
  /// not passed. Reusing the same widget instance lets Flutter skip the rebuild.
  /// The redraw cap in effect now: the user's setting, or the batching interval while
  /// frames are over budget, whichever is longer.
  Duration _effectiveInterval() {
    if (adaptiveChartBatching && FrameBudget.instance.overBudget &&
        batchedChartInterval > chartRedrawInterval) {
      return batchedChartInterval;
    }
    return chartRedrawInterval;
  }

  Widget _throttledChartBody(String symbol) {
    final key='$symbol|${widget.panel.range}';
    final interval=_effectiveInterval();
    final now=DateTime.now();
    if(_dueRedraw||interval==Duration.zero||_lastChart==null||_lastKey!=key||_lastDraw==null||
        now.difference(_lastDraw!)>=interval) {
      _dueRedraw=false;
      _trailing?.cancel();
      _trailing=null;
      _lastDraw=now;
      _lastKey=key;
      return _lastChart=_chartBody(symbol);
    }
    _trailing??=Timer(interval-now.difference(_lastDraw!),(){
      _trailing=null;
      _dueRedraw=true; // draw the latest data even if the wall clock says it's too soon
      _redraw.value++;
    });
    return _lastChart!;
  }
  @override Widget build(BuildContext context) {
    _count('card');
    final p=widget.panel;
    return Material(color:Palette.surface,borderRadius:BorderRadius.circular(10),
      clipBehavior:Clip.antiAlias,child:Stack(fit:StackFit.expand,children:[
        Column(children:[
          GestureDetector(
            onPanStart:widget.interactive?(_)=>_startGesture():null,
            onPanUpdate:widget.interactive?(d){_gestureTotal+=d.delta;widget.workspace.dragBy(p,_gestureTotal.dx,_gestureTotal.dy,widget.cellW);}:null,
            onPanEnd:widget.interactive?(_)=>widget.workspace.endGesture():null,
            onPanCancel:widget.interactive?widget.workspace.endGesture:null,
            onDoubleTap:()=>widget.workspace.toggleFullscreen(p),
            child:Container(height:42,padding:const EdgeInsets.symmetric(horizontal:11),
              decoration:const BoxDecoration(color:Palette.header,border:Border(bottom:BorderSide(color:Palette.border))),
              child:Row(children:[
                Icon(switch(p.kind){WidgetKind.chart=>Icons.show_chart,WidgetKind.table=>Icons.table_chart,WidgetKind.script=>Icons.code},size:16),
                const SizedBox(width:7),Text(switch(p.kind){WidgetKind.chart=>'CHART',WidgetKind.table=>'TABLE',WidgetKind.script=>'SCRIPT'},
                  style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,letterSpacing:1)),
                const Spacer(),
                DropdownButton<int>(value:p.channel,hint:const Text('Link'),underline:const SizedBox(),
                  items:[const DropdownMenuItem(value:-1,child:Text('Unlinked')),for(var i=0;i<4;i++)
                    DropdownMenuItem(value:i,child:Row(children:[CircleAvatar(radius:5,backgroundColor:channelColors[i]),const SizedBox(width:5),Text(channelNames[i])]))],
                  onChanged:(v){if(v!=null)widget.workspace.setChannel(p,v);}),
                PopupMenuButton<String>(onSelected:(v){if(v=='duplicate')widget.workspace.duplicate(p);if(v=='remove')widget.workspace.remove(p);},
                  itemBuilder:(_)=>[
                  PopupMenuItem(value:'duplicate',enabled:!widget.workspace.locked,child:const Text('Duplicate')),
                  PopupMenuItem(value:'remove',enabled:!widget.workspace.locked,child:const Text('Remove'))]),
              ]))),
          // Own paint layer: a chart repainting on a tick doesn't repaint the header or other cards.
          Expanded(child:RepaintBoundary(child:p.channel>=0
            ? ValueListenableBuilder<String>(
                valueListenable:widget.workspace.channelSymbols[p.channel],
                builder:(context,symbol,_) => _renderPanel(symbol))
            : _renderPanel(p.symbol))),
          if(error!=null) Padding(padding:const EdgeInsets.all(4),child:Text(error!,style:const TextStyle(color:Palette.error,fontSize:10))),
        ]),
        if(widget.interactive) ..._resizeHandles(p),
        if(widget.interactive) const Positioned(right:3,bottom:3,
          child:IgnorePointer(child:Icon(Icons.open_in_full,size:10,color:Palette.textFaint))),
      ]));
  }

  /// Eight handles: four edges and four corners. Each resizes the card live.
  List<Widget> _resizeHandles(Panel p) {
    const edge=6.0, corner=14.0;
    Widget handle(SystemMouseCursor cursor,Set<ResizeSide> sides,{double? left,double? right,double? top,double? bottom,double? width,double? height})=>
      Positioned(left:left,right:right,top:top,bottom:bottom,width:width,height:height,
        child:MouseRegion(cursor:cursor,child:GestureDetector(
          behavior:HitTestBehavior.translucent,
          onPanStart:(_)=>_startGesture(),
          onPanUpdate:(d){
            _gestureTotal+=d.delta;
            widget.workspace.resizeBy(p,sides,_gestureTotal.dx,_gestureTotal.dy,widget.cellW);
          },
          onPanEnd:(_)=>widget.workspace.endGesture(),
          onPanCancel:widget.workspace.endGesture,
          child:const SizedBox.expand())));
    return [
      handle(SystemMouseCursors.resizeUpDown,{ResizeSide.top},left:corner,right:corner,top:0,height:edge),
      handle(SystemMouseCursors.resizeUpDown,{ResizeSide.bottom},left:corner,right:corner,bottom:0,height:edge),
      handle(SystemMouseCursors.resizeLeftRight,{ResizeSide.left},top:corner,bottom:corner,left:0,width:edge),
      handle(SystemMouseCursors.resizeLeftRight,{ResizeSide.right},top:corner,bottom:corner,right:0,width:edge),
      handle(SystemMouseCursors.resizeUpLeftDownRight,{ResizeSide.top,ResizeSide.left},top:0,left:0,width:corner,height:corner),
      handle(SystemMouseCursors.resizeUpRightDownLeft,{ResizeSide.top,ResizeSide.right},top:0,right:0,width:corner,height:corner),
      handle(SystemMouseCursors.resizeUpRightDownLeft,{ResizeSide.bottom,ResizeSide.left},bottom:0,left:0,width:corner,height:corner),
      handle(SystemMouseCursors.resizeUpLeftDownRight,{ResizeSide.bottom,ResizeSide.right},bottom:0,right:0,width:corner,height:corner),
    ];
  }

  /// Runs [build] and shows this widget's error state if it throws. Used for the
  /// builders that run later during the framework's build, outside the try/catch
  /// in [_renderPanel], so one broken widget never takes down the workspace.
  Widget _guard(Widget Function() build) {
    try {
      return build();
    } catch (e) {
      return WidgetErrorTile(message: '$e', onRetry: () => setState(() {}));
    }
  }

  Widget _renderPanel(String symbol) {
    widget.panel.symbol = symbol;
    if (widget.market.dropped) return _state('Feed connection dropped', Icons.cloud_off);
    return _guard(() => switch(widget.panel.kind) {
      WidgetKind.chart => _chart(symbol),
      WidgetKind.table => _table(),
      WidgetKind.script => _script(),
    });
  }
  Widget _state(String s,IconData i)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    Icon(i,color:Palette.textFaint),const SizedBox(height:8),Text(s,style:const TextStyle(color:Palette.textMuted,fontSize:12)),
  ]));
  Widget _loading(String s)=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
    const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)),
    const SizedBox(height:8),Text(s,style:const TextStyle(color:Palette.textMuted,fontSize:12)),
  ]));

  // ---- Chart ---------------------------------------------------------------
  Widget _chart(String symbol) {
    if (!widget.market.hasData(symbol)) return _loading('Loading $symbol…');
    return Padding(padding:const EdgeInsets.fromLTRB(12,8,12,4),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Wrap(crossAxisAlignment:WrapCrossAlignment.center,children:[_symbolPicker(symbol),
          for(final r in ['1m','5m','15m']) TextButton(
            style:TextButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:6),
              minimumSize:Size.zero,tapTargetSize:MaterialTapTargetSize.shrinkWrap),
            onPressed:()=>setState(()=>widget.panel.range=r),
            child:Text(r,style:TextStyle(fontSize:11,color:widget.panel.range==r?Palette.accent:Palette.textMuted))) ]),
        Expanded(child:AnimatedBuilder(
          animation:Listenable.merge([widget.market.listen(symbol),_redraw]),
          builder:(context,_)=>_guard(()=>_throttledChartBody(symbol)))),
      ]));
  }
  Widget _chartBody(String symbol) {
    _count('chart');
    final pts=widget.market.history(symbol,widget.panel.range);
    if(pts.isEmpty) return _state('No ticks in the last ${widget.panel.range}',Icons.show_chart);
    final start=pts.first.time;
    final spots=[for(final t in pts) FlSpot(t.time.difference(start).inMilliseconds/1000,t.value)];
    final span=max(spots.last.x,1.0);
    final ys=pts.map((t)=>t.value).toList();
    return LineChart(LineChartData(
      minX:0,maxX:span,
      minY:ys.reduce(min)-1,maxY:ys.reduce(max)+1,
      gridData:const FlGridData(show:true,drawVerticalLine:false),
      lineTouchData:const LineTouchData(enabled:false), // no hover or tap work on live data
      titlesData:FlTitlesData(
        topTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
        leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
        rightTitles:AxisTitles(sideTitles:SideTitles(showTitles:false)),
        bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:18,interval:span/4,
          getTitlesWidget:(v,meta)=>Padding(padding:const EdgeInsets.only(top:4),
            child:Text(_clock(start.add(Duration(milliseconds:(v*1000).round()))),
              style:const TextStyle(fontSize:9,color:Palette.textFaint))))),
      ),
      borderData:FlBorderData(show:false),
      lineBarsData:[LineChartBarData(spots:spots,isCurved:false,barWidth:2,dotData:const FlDotData(show:false),
        color:Palette.accent,belowBarData:BarAreaData(show:true,color:Palette.accentFill))],
    ), duration:Duration.zero); // no tween per tick: the new points appear immediately
  }

  // ---- Table ---------------------------------------------------------------
  static const _tableRowHeight=26.0;
  /// Rebuilds once per feed tick. The table reads every symbol, so it listens to the
  /// market's tick batch rather than to each symbol separately.
  Widget _table()=>AnimatedBuilder(
    animation:widget.market.batch,
    builder:(context,_)=>_guard(_tableBody));
  /// Symbol dropdown. Changing it goes through the workspace, so linked widgets follow.
  Widget _symbolPicker(String value)=>DropdownButton<String>(
    value:value,isDense:true,underline:const SizedBox(),
    style:const TextStyle(fontWeight:FontWeight.bold,fontSize:13,color:Palette.textPrimary),
    items:[for(final s in symbols) DropdownMenuItem(value:s,child:Text(s))],
    onChanged:(v){if(v!=null)widget.workspace.selectSymbol(widget.panel,v);});
  Widget _tableBody() {
    _count('table');
    if (!symbols.any(widget.market.hasData)) return _loading('Loading prices…');
    final rows=<Map<String,Object>>[];
    for (final s in symbols) {
      final h=widget.market.history(s,'15m');
      if (h.isEmpty) continue;
      final last=h.last.value, first=h.first.value;
      rows.add({'symbol':s,'last':last,'change':last-first,'pct':first==0?0.0:(last-first)/first*100});
    }
    if (rows.isEmpty) return _state('No prices in the last 15m',Icons.table_chart);
    rows.sort((a,b){final c=(a[widget.panel.sortBy] as Comparable).compareTo(b[widget.panel.sortBy] as Comparable);return widget.panel.ascending?c:-c;});
    // Rows that fit are shown; the rest are summarised, so nothing is clipped.
    return LayoutBuilder(builder:(context,c){
      final fit=(c.maxHeight/_tableRowHeight).floor()-1; // one line is the header
      final visible=rows.length<=fit?rows.length:max(0,fit-1);
      final hidden=rows.length-visible;
      return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        _tableHeader(),
        for(final r in rows.take(visible)) _tableRow(r),
        if(hidden>0) SizedBox(height:_tableRowHeight,child:Center(child:Text('+$hidden more',
          style:const TextStyle(fontSize:10,color:Palette.textFaint)))),
      ]);
    });
  }
  Widget _tableHeader()=>Container(height:_tableRowHeight,
    decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:Palette.border))),
    child:Row(children:[
      for(final (key,label) in const [('symbol','SYMBOL'),('last','LAST'),('change','CHANGE'),('pct','PCT')])
        Expanded(child:InkWell(
          onTap:()=>setState((){
            if(widget.panel.sortBy==key){widget.panel.ascending=!widget.panel.ascending;}
            else {widget.panel.sortBy=key;widget.panel.ascending=true;}
          }),
          child:Padding(padding:const EdgeInsets.symmetric(horizontal:6),child:Align(alignment:Alignment.centerLeft,
            child:Text(widget.panel.sortBy==key?'$label ${widget.panel.ascending?'▲':'▼'}':label,
              overflow:TextOverflow.ellipsis,
              style:const TextStyle(fontSize:10,fontWeight:FontWeight.bold,color:Palette.textMuted)))))),
    ]));
  Widget _tableRow(Map<String,Object> r) {
    final selected=widget.panel.symbol==r['symbol'];
    final change=r['change'] as double;
    return InkWell(
      onTap:()=>widget.workspace.selectSymbol(widget.panel,r['symbol'] as String),
      child:Container(height:_tableRowHeight,color:selected?Palette.accentSoft:null,
        child:Row(children:[
          _cell('${r['symbol']}'),
          _cell((r['last'] as double).toStringAsFixed(2)),
          _cell(change.toStringAsFixed(2)),
          _cell('${(r['pct'] as double).toStringAsFixed(2)}%'),
        ])));
  }
  Widget _cell(String s)=>Expanded(child:Padding(padding:const EdgeInsets.symmetric(horizontal:6),
    child:Align(alignment:Alignment.centerLeft,child:Text(s,overflow:TextOverflow.ellipsis,
      style:const TextStyle(fontSize:12)))));

  // ---- Script --------------------------------------------------------------
  Map<String,double> _paramValues() {
    final declared=parseParams(widget.panel.code);
    return {for(final p in declared) p.name: widget.panel.params[p.name] ?? p.defaultValue};
  }
  void _run() {
    try {
      final result=runScript(widget.panel.code,widget.market,_paramValues());
      setState((){error=null;_scriptResult=result;_log('ran: ${result['type']}');});
    } catch(e) {
      setState((){error='Script error: $e';_log('error: $e');});
    }
  }
  Widget _scriptOutput()=>_guard(() {
    final result=_scriptResult;
    if(result==null) return const Padding(
      padding:EdgeInsets.all(10),
      child:Text('Run the script to see its output.',style:TextStyle(color:Palette.textFaint,fontSize:11)));
    if(result['type']=='stat') return Card(
      color:Palette.cardTint,
      child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('${result['label']}',style:const TextStyle(color:Palette.textMuted,fontSize:11)),
        const SizedBox(height:5),Text('${result['value']}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
        const Text('Stat tile output',style:TextStyle(color:Palette.textFaint,fontSize:10)),
      ])));
    final rows=result['rows'] as List;
    return DataTable(columns:const [DataColumn(label:Text('SYMBOL')),DataColumn(label:Text('VALUE'))],
      rows:[for(final row in rows)DataRow(cells:[DataCell(Text('${row['symbol']}')),
        DataCell(Text((row['value'] as num).toStringAsFixed(2)))])]);
  });
  Widget _paramForm() {
    final declared=parseParams(widget.panel.code);
    if(declared.isEmpty) return const Padding(padding:EdgeInsets.fromLTRB(12,4,12,8),
      child:Text('Add "param name: 10 [0..100]" to the script to create a setting.',
        style:TextStyle(color:Palette.textFaint,fontSize:10)));
    final values=_paramValues();
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      for(final p in declared) Padding(padding:const EdgeInsets.symmetric(horizontal:12),child:Row(children:[
        SizedBox(width:72,child:Text(p.name,overflow:TextOverflow.ellipsis,
          style:const TextStyle(fontSize:10,color:Palette.textMuted))),
        Expanded(child:Slider(min:p.min,max:p.max,
          value:(values[p.name] ?? p.defaultValue).clamp(p.min,p.max).toDouble(),
          onChanged:(v){widget.workspace.setParam(widget.panel,p.name,v);_run();})),
        SizedBox(width:40,child:Text((values[p.name] ?? p.defaultValue).toStringAsFixed(1),
          style:const TextStyle(fontSize:10))),
      ])),
    ]);
  }
  Widget _consoleView()=>Container(
    margin:const EdgeInsets.fromLTRB(10,4,10,8),padding:const EdgeInsets.all(6),
    constraints:const BoxConstraints(maxHeight:90),
    decoration:BoxDecoration(color:Palette.console,borderRadius:BorderRadius.circular(6)),
    child:_console.isEmpty
      ? const Text('Console is empty.',style:TextStyle(color:Palette.textFaint,fontSize:10))
      : SingleChildScrollView(reverse:true,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          for(final line in _console) Text(line,style:const TextStyle(fontFamily:'monospace',fontSize:10,color:Palette.textSecondary)),
        ])));
  Widget _script()=>Column(children:[
    Expanded(flex:3,child:Padding(padding:const EdgeInsets.all(8),child:TextField(
      controller:_editor, focusNode:_editorFocus,
      maxLines:null, expands:true, style:const TextStyle(fontFamily:'monospace',fontSize:12),
      decoration:const InputDecoration(border:OutlineInputBorder(),hintText:'Enter script spec…'),
      onChanged:(v){
        widget.panel.code=v;
        _saveTimer?.cancel();
        _saveTimer=Timer(const Duration(milliseconds:500),(){_log('autosaved');widget.workspace.persist();});
      }))),
    Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,
      spacing:10,children:[
      FilledButton.tonal(onPressed:_run,child:const Text('Run script')),
      _symbolPicker(widget.panel.symbol),
      const Text('Autosaved locally',style:TextStyle(fontSize:10,color:Palette.textFaint)),
    ])),
    Expanded(flex:2,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      _scriptOutput(),
      _paramForm(),
      _consoleView(),
    ]))),
  ]);
}
