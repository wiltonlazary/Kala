package kala.debug;

import kala.input.Keyboard;
import kala.input.Mouse;
import kala.math.color.Color;
import kala.math.Matrix;
import kala.math.Rect;
import kala.util.types.Pair;
import kha.Canvas;
import kha.FastFloat;
import kha.Font;
import kha.graphics2.Graphics;
import kha.Image;
import kha.Scheduler;

#if (debug || kala_debug)
@:access(kala.CallbackHandle)
class Debugger {
	
	public static inline var NORMAL = 0;
	public static inline var MAXIMIZED = 1;
	public static inline var MINIMIZED = 2;
	
	public var visible(default, set):Bool = false;
	
	public var rect(default, null):Rect = new Rect(0, 0, 600, 400);
	
	public var fontSize:Int = 18;
	public var font:Font;
	var _font:Font;
	
	public var tab:DebugConsoleTab = CONSOLE;
	
	public var state:Int = NORMAL; // 0 - Normal, 1 - Maximized, 2 - Minimized.

	private var _dragging:Bool = false;
	private var _dragPointX:FastFloat;
	private var _dragPointY:FastFloat;
	
	private var _resizing:Bool = false;
	private var _resizePointX:FastFloat;
	private var _resizePointY:FastFloat;
	
	private var _maxRect:Rect = new Rect();
	private var _minRect:Rect = new Rect();
	
	private var _command:String = "";
	private var _cmdFieldVisible:Bool = false;
	private var _cmdCursorVisible:Bool = true;
	private var _cmdCursorTimeTask:Int;
	private var _cmdCursorPos:Int = 0;
	private var _cmdFieldInFocus:Bool = false;
	
	private var _backspacePressingTime:FastFloat = 0;
	
	private var _draggingHHandle:Bool = false;
	private var _draggingVHandle:Bool = false;
	private var _handleDragPoint:FastFloat;
	
	private var _contentBuffer:Image;
	private var _contentHPos:FastFloat = 0;
	private var _contentVPos:FastFloat = 0;
	
	private var _contentWidth(get, never):FastFloat;
	private var _contentWidthtCached:Bool;
	private var _cachedContentWidth:FastFloat;
	
	private var _contentHeight(get, never):FastFloat;
	private var _contentHeightCached:Bool;
	private var _cachedContentHeight:FastFloat;
	
	private var _consoleOutputLines:Array<Pair<String, UInt>> = new Array<Pair<String, UInt>>();
	
	public function new() {
		Keyboard.onStartPressing.notifyPrivateCB(this, onKeyboardInput);
		
		Kala.world.onFirstFrame.notifyPrivateCB(this, function(_) {
			_contentBuffer = Image.createRenderTarget(Std.int(rect.width - 15), Std.int(rect.height - 15 - 24 * 2));
		});
	}
	
	public function pushConsoleOutput(string:String, color:Color):Void {
		if (_consoleOutputLines.length > 150) _consoleOutputLines.splice(0, 1);
		_consoleOutputLines.push(new Pair(string, color));
	}
	
	public function draw(canvas:Canvas):Void {
		_contentWidthtCached =
		_contentHeightCached =
		_cmdFieldVisible = false;
		
		var rect = this.rect;
		
		if (state == MAXIMIZED) { 
			_maxRect.set(0, 0, canvas.width, canvas.height);
			rect = _maxRect;
		} else if (state == MINIMIZED) {
			_minRect.set(rect.x, rect.y, rect.width, 24);
			rect = _minRect;
		}
		
		if (rect.x < 0) rect.x = 0;
		else if (rect.x > canvas.width - rect.width) rect.x = canvas.width - rect.width;
		
		if (rect.y < 0) rect.y = 0;
		else if (rect.y > canvas.height - rect.height) rect.y = canvas.height - rect.height;
		
		var g = canvas.g2;
		g.transformation = Matrix.translation(rect.x, rect.y);
		g.opacity = 1;
		
		// Title bar
		
		g.color = 0x66666666;
		g.fillRect(0, 0, rect.width , 24);
		
		
		// Dragging
		
		var mx = Mouse.x;
		var my = Mouse.y;
		var ma = new Rect(rect.x, rect.y, rect.width, 24);
		
		if (!_dragging && Mouse.didLeftClickRect(ma)) {
			_dragging = true;
			_dragPointX = mx - ma.x;
			_dragPointY = my - ma.y;
		}
		
		if (_dragging && Mouse.LEFT.pressed) {
			this.rect.x = mx - _dragPointX;
			this.rect.y = my - _dragPointY;
		} else {
			_dragging = false;
		}
		
		// Close button
		g.color = Color.WHITE;
		
		ma.set(rect.x + rect.width - 30, rect.y, 30, 24);
		if (Mouse.isHoveringRect(ma)) {
			g.color = 0x66999999;
			g.fillRect(rect.width - 30, 0, 30, 24);
			g.color = Color.WHITE;
			
			if (Mouse.LEFT.justPressed) visible = false;
		}
		
		g.drawLine(rect.width - 20, 7, rect.width - 10, 17, 1);
		g.drawLine(rect.width - 20, 17, rect.width - 10, 7, 1);
		
		// Restore / Maximize button
		
		ma.x -= 30;
		if (Mouse.isHoveringRect(ma)) {
			g.color = 0x66999999;
			g.fillRect(ma.x - rect.x, 0, 30, 24);
			g.color = Color.WHITE;
			
			if (Mouse.LEFT.justPressed) {
				if (state == MAXIMIZED) state = NORMAL;
				else state = MAXIMIZED;
			}
		}
		
		if (state == MAXIMIZED) {
			// Restore button
			g.drawLine(rect.width - 48, 9, rect.width - 47, 7, 1);
			g.drawLine(rect.width - 48, 7, rect.width - 40, 7, 1);
			g.drawLine(rect.width - 40, 7, rect.width - 40, 15, 1);
			g.drawLine(rect.width - 40, 15, rect.width - 42, 15, 1);
			g.drawRect(rect.width - 50, 9, 8, 8, 1);
		} else {
			// Maximize button
			g.drawRect(rect.width - 50, 7, 10, 10, 1);
		}
		
		// Minimize button
		
		ma.x -= 30;
		if (Mouse.isHoveringRect(ma)) {
			g.color = 0x66999999;
			g.fillRect(ma.x - rect.x, 0, 30, 24);
			g.color = Color.WHITE;
			
			if (Mouse.LEFT.justPressed) {
				if (state == MINIMIZED) {
					state = NORMAL;
					rect = this.rect;
				} else state = MINIMIZED;
			}
		}
		
		g.drawLine(rect.width - 80, 12, rect.width - 70, 12, 1);
		
		// Tab
		
		g.font = _font = font == null ? Kala.defaultFont : font;
		g.fontSize = fontSize;
		
		var s = '  -  FPS: ${Kala.fps}';
	
		switch(tab) {
			case CONSOLE:
				s = "CONSOLE" + s;
				if (state != MINIMIZED) drawConsoleOutput(rect, g);
				
			case DRAWING_SETTINGS:
				s = "DRAWING SETTINGS" + s;
				
			case MONITOR:
				s = "MONITOR" + s;
				
			case PROFILER:
				s = "PROFILER" + s;
		}
		
		g.drawString(s, 10, (24 - g.font.height(g.fontSize)) / 2);
		
		if (state != MINIMIZED) {
			g.drawImage(_contentBuffer, 0, 24);
		}
		
		// Content
		
		if (state != MINIMIZED) {
			drawScrollHandle(rect, g);
			updateContentBufferSize(rect.width - 15, rect.height  - 15 - 24 * (_cmdFieldVisible ? 2 : 1));
		}
		
		// Resize button
		
		if (state == NORMAL) {
			g.color = Color.WHITE;
			
			g.drawLine(rect.width - 9, rect.height, rect.width, rect.height - 9, 1);
			g.drawLine(rect.width - 6, rect.height, rect.width, rect.height - 6, 1);
			g.drawLine(rect.width - 3, rect.height, rect.width, rect.height - 3, 1);
			
			ma.set(rect.x + rect.width - 9, rect.y + rect.height - 9, 9, 9);
			if (!_resizing && Mouse.didLeftClickRect(ma)) {
				_resizing = true;
				_resizePointX = rect.width - mx + rect.x;
				_resizePointY = rect.height - my + rect.y;
			}
			
			if (_resizing && Mouse.LEFT.pressed) {
				rect.width = mx - rect.x + _resizePointX;
				rect.height = my - rect.y + _resizePointY;
				
				if (rect.width < 300) rect.width = 300;
				if (rect.height < 200) rect.height = 200;
			} else {
				_resizing = false;
			}
		}
	}
	
	inline function updateContentBufferSize(width:FastFloat, height:FastFloat):Void {
		if (width != _contentBuffer.width || height != _contentBuffer.height) {
			_contentBuffer.unload();
			_contentBuffer = Image.createRenderTarget(
				Std.int(width), Std.int(height)
			);
		}
	}
	
	function drawScrollHandle(rect:Rect, g:Graphics):Void {
		var vbarX = rect.width - 15;
		var vbarLenght = rect.height - 15 - 24 * (_cmdFieldVisible ? 2 : 1);
		var hbarY = rect.height - 15 - (_cmdFieldVisible ? 24 : 0);
		var hbarLenght = vbarX;
		
		g.color = 0x66444444;
		g.fillRect(vbarX, 24, 15, vbarLenght + 15);
		g.fillRect(0, hbarY, hbarLenght, 15);
		
		g.color = Color.WHITE;
		
		var mx = Mouse.x;
		var my = Mouse.y;
		var ma = new Rect(0, 0, 0, 0);
		
		// Up button
		
		g.fillTriangle(
			vbarX + 2, 24 + 10, 
			rect.width - 7, 24 + 5,
			rect.width - 2, 24 + 10
		);
		
		// Down button
		
		g.fillTriangle(
			vbarX + 2, 24 + vbarLenght - 10,
			rect.width - 7, 24 + vbarLenght - 5,
			rect.width - 2, 24 + vbarLenght - 10
		);
		
		// Left button
		
		g.fillTriangle(
			10, hbarY + 2,
			5, hbarY + 7,
			10, hbarY + 15 - 2
		);
		
		// Right button
		
		g.fillTriangle(
			hbarLenght - 10, hbarY + 2,
			hbarLenght - 5, hbarY + 7,
			hbarLenght - 10, hbarY + 15 - 2
		);
		
		// Vertical handle
		
		g.color = 0x55aaaaaa;
		
		var contentHeight = _contentHeight;
		var fullHeightVisible = _contentBuffer.height >= contentHeight;
		var ratio = fullHeightVisible ? 1 : _contentBuffer.height / contentHeight;
		var handleMaxLenght = vbarLenght - 15 * 2;
		var handleLenght = ratio * handleMaxLenght; if (handleLenght < 24) handleLenght = 24;
		
		if (handleMaxLenght > handleLenght) {
			var space = handleMaxLenght - handleLenght;
			var handlePos = fullHeightVisible ? 0 : _contentVPos * space;

			g.fillRect(vbarX, 24 + 15 + handlePos, 15, handleLenght);
			
			ma.set(rect.x + vbarX, rect.y + 24 + 15 + handlePos, 15, handleLenght);
			if (!_draggingVHandle && Mouse.didLeftClickRect(ma)) {
				_draggingVHandle = true;
				_handleDragPoint = my - ma.y;
			}
			
			if (_draggingVHandle && !fullHeightVisible) {
				if (Mouse.LEFT.pressed) {
					_contentVPos = (my - _handleDragPoint - (rect.y + 24 + 15)) / space;
					if (_contentVPos < 0) _contentVPos = 0;
					else if (_contentVPos > 1) _contentVPos = 1;
				} else {
					_draggingVHandle = false;
				}
			} else {
				_contentVPos = (_contentVPos * space - Mouse.wheel * 2) / space;
				if (_contentVPos < 0) _contentVPos = 0;
				else if (_contentVPos > 1) _contentVPos = 1;
				
				_draggingVHandle = false;
			}
		}
		
		// Horizontal handle
		
		var contentWidth = _contentWidth;
		var fullWidthVisible = _contentBuffer.width >= contentWidth;
		var ratio = fullWidthVisible ? 1 : _contentBuffer.width / contentWidth;
		var handleMaxLenght = hbarLenght - 15 * 2;
		var handleLenght = ratio * handleMaxLenght; if (handleLenght < 24) handleLenght = 24;
		
		if (handleMaxLenght > handleLenght) {
			var space = handleMaxLenght - handleLenght;
			var handlePos = fullWidthVisible ? 0 : _contentHPos * space;
			
			g.fillRect(15 + handlePos, hbarY, handleLenght, 15);
			
			ma.set(rect.x + 15 + handlePos, rect.y + hbarY, handleLenght, 15);
			if (!_draggingHHandle && Mouse.didLeftClickRect(ma)) {
				_draggingHHandle = true;
				_handleDragPoint = mx - ma.x;
			}
			
			if (_draggingHHandle && !fullWidthVisible && Mouse.LEFT.pressed) {
				_contentHPos = (mx - _handleDragPoint - (rect.x + 15)) / space;
				if (_contentHPos < 0) _contentHPos = 0;
				else if (_contentHPos > 1) _contentHPos = 1;
			} else {
				_draggingHHandle = false;
			}
		}
	}
	
	function drawCMDField(rect:Rect, g:Graphics):Void {
		_cmdFieldVisible = true;
		
		if (Keyboard.TAB.justPressed) _cmdFieldInFocus = true;
		
		if (Mouse.LEFT.justPressed) {
			_cmdFieldInFocus = Mouse.isHoveringRect(rect);
		}
		
		g.color = 0xaa333333;
		g.fillRect(0, rect.height - 24, rect.width , 24);
		
		g.color = Color.WHITE;
		var s = _command;
		var i = 0;
		while (g.font.width(g.fontSize, s) > rect.width) s = s.substr(++i);
		g.drawString(s, 5, rect.height - 24 + (24 - g.font.height(g.fontSize)) / 2);
		
		// Draw the cursor.
		if (_cmdFieldInFocus && _cmdCursorVisible) {
			g.fillRect(5 + g.font.width(g.fontSize, s.substr(0, _cmdCursorPos)), rect.height - 20, 2, 16);
		}
		
		//
		if (Keyboard.BACKSPACE.pressed) {
			_backspacePressingTime += Kala.delta;
			if (_backspacePressingTime >= 0.25 && _command.length > 0) {
				_command = _command.substr(0, _command.length - 1);
			}
		} else {
			_backspacePressingTime = 0;
		}
	}

	function drawConsoleOutput(rect:Rect, g:Graphics):Void {
		drawCMDField(rect, g);
		
		var framebufferGraphics = g;
		g = _contentBuffer.g2;
		
		framebufferGraphics.end();
		
		g.begin();
		g.color = 0x66333333;
		g.fillRect(0, 0, _contentBuffer.width, _contentBuffer.height);
		
		if (_consoleOutputLines.length > 0) {
			g.font = framebufferGraphics.font;
			g.fontSize = framebufferGraphics.fontSize;
			
			var lineHeight = getLineHeight();
			var visibleLineCount = Math.floor(_contentBuffer.height / lineHeight);
			if (visibleLineCount > _consoleOutputLines.length) visibleLineCount = _consoleOutputLines.length;
			var lineIndex = Math.floor(_contentVPos * (_consoleOutputLines.length - visibleLineCount));
			var lineX = 10 + _contentHPos * (_contentBuffer.width - (_contentWidth + 20));
			var lineContent:Pair<String, UInt>;
			
			for (i in 0...visibleLineCount) {
				lineContent = _consoleOutputLines[lineIndex + i];
				g.color = lineContent.b;
				g.drawString(lineContent.a, lineX, i * lineHeight + 4);
			}
		}

		g.end();
		
		framebufferGraphics.begin(false);
	}
	
	function execCMD(command:String):Void {
		if (command.length < 1) return;
	}
	
	function onKeyboardInput(key:Key):Void {
		switch(key) {
			case CHAR(c):
				if (c == '`' || c == 'à') {
					visible = !visible;
					return;
				}
				
			default:
		}
		
		if (tab == CONSOLE) onConsoleInput(key);
	}
	
	function onConsoleInput(key:Key):Void {
		if (!_cmdFieldInFocus || state == MINIMIZED) return;
		
		switch(key) {
			case CHAR(c):
				_command += c;
				_cmdCursorPos++;
			
			case BACKSPACE:
				if (_command.length > 0 && _backspacePressingTime < 0.25 && _command.length > 0) {
					_command = _command.substr(0, _command.length - 1);
					_cmdCursorPos--;
				}
				
			case LEFT:
				if (_cmdCursorPos > 0) _cmdCursorPos--;
				
			case RIGHT:
				if (_cmdCursorPos < _command.length) _cmdCursorPos++;

			case ENTER:
				execCMD(_command);
				_command = "";
				_cmdCursorPos = 0;
				
			default:
		}
	}
	
	inline function getLineHeight():FastFloat {
		return _font.height(fontSize) + 4;
	}
	
	function set_visible(value:Bool):Bool {
		if (value) {
			if (!visible) {
				_cmdCursorTimeTask = Scheduler.addTimeTask(function() {
					_cmdCursorVisible = !_cmdCursorVisible;
				}, 0, 0.5);
			}
		} else {
			if (visible) {
				Scheduler.removeTimeTask(_cmdCursorTimeTask);
			}
		}
		
		return visible = value;
	}
	
	function get__contentWidth():FastFloat {
		if (_contentWidthtCached) return _cachedContentWidth;
		
		_contentWidthtCached = true;
		
		switch(tab) {
			case CONSOLE:
				_cachedContentWidth = 0;
				var lineWidth:Float;
				for (line in _consoleOutputLines) {
					if ((lineWidth = _font.width(fontSize, line.a)) > _cachedContentWidth) {
						_cachedContentWidth = lineWidth;
					}
				}
				
				return _cachedContentWidth;
				
			default:
				return 0;
		}
	}
	
	function get__contentHeight():FastFloat {
		if (_contentHeightCached) return _cachedContentHeight;
		
		_contentHeightCached = true;
		
		switch(tab) {
			case CONSOLE:
				return _cachedContentHeight = getLineHeight() * _consoleOutputLines.length;
				
			default:
				return 0;
		}
	}
	
}

enum DebugConsoleTab {
	
	CONSOLE;
	DRAWING_SETTINGS;
	MONITOR;
	PROFILER;
	
}
#end