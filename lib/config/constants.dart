import 'package:flutter/material.dart';

const symbols = ['AAA', 'BBB', 'CCC'];
const channelColors = [Color(0xffDB2777), Color(0xff2563EB), Color(0xff059669), Color(0xffB45309)];
const channelNames = ['Pink', 'Blue', 'Green', 'Amber'];

const rowHeight = 56.0;

/// Shortest time between redraws of a live chart. Zero (the default) redraws on every
/// feed tick. A larger value skips the ticks in between and draws the latest data when
/// the interval ends, trading feed smoothness for lower paint cost.
Duration chartRedrawInterval = Duration.zero;

/// When frames run over budget (see FrameBudget), charts redraw no more often than this.
/// Must be longer than one feed tick (150 ms at the default rate) to batch anything.
/// Ignored while frames are within budget, so the feed keeps its normal feel.
const batchedChartInterval = Duration(milliseconds: 500);

/// Turns the over-budget batching on or off.
const adaptiveChartBatching = true;
