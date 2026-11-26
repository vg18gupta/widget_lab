import 'package:flutter/material.dart';
import 'package:tradl_widget_lab/models/constants.dart';

class GridPainter extends CustomPainter {
  GridPainter(this.cellW); final double cellW;
  @override void paint(Canvas canvas,Size size){
    final p=Paint()..color=const Color(0xff263149)..strokeWidth=.5;
    for(var x=0;x<=12;x++) canvas.drawLine(Offset(x*cellW,0),Offset(x*cellW,size.height),p);
    for(var y=0.0;y<size.height;y+=rowHeight) canvas.drawLine(Offset(0,y),Offset(size.width,y),p);
  }
  @override bool shouldRepaint(covariant GridPainter old)=>old.cellW!=cellW;
}
