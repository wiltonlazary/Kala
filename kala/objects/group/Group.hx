package kala.objects.group;

import kala.DrawingData;
import kala.math.color.BlendMode;
import kala.math.Matrix;
import kala.objects.group.View;
import kala.objects.Object;
import kala.math.color.Color;
import kha.Canvas;
import kha.FastFloat;
import kha.Image;
import kha.graphics2.ImageScaleQuality;

typedef GenericGroup = Group<Object>;

interface IGroup extends IObject {
	
	public var transformationEnable:Bool;
	
	public var colorBlendMode:BlendMode;
	public var colorAlphaBlendMode:BlendMode;
	
	public var timeScale:FastFloat;
	
	public var views(default, null):Array<View>;
	
	public function addView(view:View, pos:Int = -1):Void;
	public function removeView(view:View, splice:Bool = false):View;
	
	private function _add(obj:Object, pos:Int = -1):Void;
	private function _remove(obj:Object, spilce:Bool = false):Void;
	
}

@:access(kala.math.color.Color)
class Group<T:Object> extends Object implements IGroup {
	
	public var transformationEnable:Bool;
	
	public var colorBlendMode:BlendMode;
	public var colorAlphaBlendMode:BlendMode;
	
	public var factoryFunction:Void->T;
	
	public var members(default, null):Array<T> = new Array<T>();
	public var views(default, null):Array<View> = new Array<View>();
	
	public function new(transformationEnable:Bool = false, ?factoryFunction:Void->T) {
		super();
		isGroup = true;
		this.transformationEnable = transformationEnable;
		this.factoryFunction = factoryFunction;
	}
	
	override public function reset(resetBehaviors:Bool = false):Void {
		super.reset(resetBehaviors);
		color = Color.WHITE;
		colorBlendMode = BlendMode.MULTI_2X;
		colorAlphaBlendMode = null;
	}
	
	override public function destroy(destroyBehaviors:Bool = true):Void {
		super.destroy(destroyBehaviors);
		
		while (members.length > 0) members.pop().destroy(destroyBehaviors);
		while (views.length > 0) views.pop().destroy(destroyBehaviors);
		
		members = null;
		views = null;
	}
	
	override public function update(elapsed:FastFloat):Void {
		var i = 0;
		var child:T;
		while (i < members.length) {
			child = members[i];

			if (child == null) {
				members.splice(i, 1);
				continue;
			}
			
			if (child.alive && child.active) {
				child.callUpdate(child.groupTimeScaleSkipped ? originalDelta : elapsed);
			}
			
			i++;
		}
		
		i = 0;
		var view:View;
		while (i < views.length) {
			view = views[i];
			
			if (view == null) {
				views.splice(i, 1);
				continue;
			}

			if (view.alive && view.active) {
				view.callUpdate(view.groupTimeScaleSkipped ? originalDelta : elapsed);
			}

			i++;
		}
	}
	
	override public function draw(data:DrawingData, canvas:Canvas):Void {
		var g2 = canvas.g2;

		if (transformationEnable) {
			if (data.transformation == null) data.transformation = _cachedDrawingMatrix = matrix;
			else data.transformation = _cachedDrawingMatrix = data.transformation.multmat(matrix);
		
			if (data.color == null) {
				data.color = color;
			} else {
				data.color = Color.getBlendColor(color, data.color, data.colorBlendMode, data.colorAlphaBlendMode);
			}
			
			data.colorBlendMode = colorBlendMode;
			data.colorAlphaBlendMode = colorAlphaBlendMode;
		
			data.opacity = opacity * data.opacity;
		}
		
		if (antialiasing) data.antialiasing = true;
		
		if (views.length == 0) {
			for (child in members) {
				if (child == null) continue;
	
				if (child.alive && child.isVisible()) {
					child.callDraw(data, canvas);
				}
			}
		} else {
			g2.end();
			
			var viewBuffer:Image;
			var matrix:Matrix;
			
			for (view in views) {
				if (view == null) continue;
				
				viewBuffer = view.viewBuffer;
				
				if (data.transformation == null) {
					data.transformation = Matrix.translation(
						-view.viewport.x,
						-view.viewport.y
					);
				} else {
					data.transformation = data.transformation.multmat(
						Matrix.translation( -view.viewport.x, -view.viewport.y)
					);
				}

				viewBuffer.g2.begin(true, view.transparent ? 0 : (255 << 24 | view.bgColor));
				for (child in members) {
					if (child == null) continue;
					
					if (child.alive && child.isVisible()) {
						child.callDraw(data, viewBuffer);
					}
				}
				viewBuffer.g2.end();
			}
			
			g2.begin(false);
			
			data.transformation = data.transformation;
			
			for (view in views) {
				if (view == null) continue;
				
				if (view.alive && view.isVisible()) {
					view.callDraw(data, canvas);
				}
			}
		}
	}
	
	override function callDraw(data:DrawingData, canvas:Canvas):Void {
		super.callDraw(data.clone(), canvas);
	}
	
	public function createAlive():T {
		for (obj in members) {
			if (!obj.alive) {
				obj.revive();
				return obj;
			}
		}
		
		if (factoryFunction != null) {
			var obj = factoryFunction();
			add(obj);
			return obj;
		}
		
		return null;
	}
	
	public function add(obj:T, pos:Int = -1):Void {
		if (members.indexOf(obj) != -1) return;
		
		if (pos == -1) members.push(obj);
		else members.insert(pos, obj);
	}
	
	public function swap(swappedObj:T, obj:T):Bool {
		var index = members.indexOf(swappedObj);
		
		if (index == -1) return false;
		
		members[index] = obj;
		swappedObj.firstFrameExecuted = false;
		
		return true;
	}
	
	public function remove(obj:T, splice:Bool = false):T {
		var index = members.indexOf(obj);
		
		if (index == -1) return null;
		
		if (splice) members.splice(index, 1);
		else members[index] = null;
		
		obj.firstFrameExecuted = false;
		
		return obj;
	}
	
	/**
	 * Call kill() on every alive member.
	 *
	 * @param	killSelf	If set to true, will also kill this group. DEFAULT: false
	 */
	public function killAll(killSelf:Bool = false):Void {
		for (member in members) {
			if (member.alive) member.kill();
		}
		
		if (killSelf) kill();
	}
	
	public function addView(view:View, pos:Int = -1):Void {
		if (views.indexOf(view) != -1) return null;
		
		if (pos == -1) views.push(view);
		else views.insert(pos, view);
	}
	
	public function removeView(view:View, splice:Bool = false):View {
		var index = views.indexOf(view);
		
		if (index == -1) return null;
		
		if (splice) views.splice(index, 1);
		else views[index] = null;
		
		view.firstFrameExecuted = false;
		
		return view;
	}
	
	public function countAlive():Int {
		var c = 0;
		for (member in members) if (member.alive) c++;
		return c;
	}
	
	public function countDead():Int {
		var c = 0;
		for (member in members) if (!member.alive) c++;
		return c;
	}
	
	public inline function iterator():Iterator<T> {
		return members.iterator();
	}
	
	//
	
	@:noCompletion 
	function _add(obj:Object, pos:Int = -1):Void {
		add(cast obj, pos);
	}
	
	@:noCompletion 
	function _remove(obj:Object, spilce:Bool = false):Void {
		remove(cast obj, spilce);
	}
	
}