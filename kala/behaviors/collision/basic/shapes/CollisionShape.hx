package kala.behaviors.collision.basic.shapes;

import kala.behaviors.collision.BaseCollisionShape;
import kala.behaviors.collision.basic.shapes.ShapeType;
import kala.math.Matrix;
import kha.Canvas;
import kha.FastFloat;

@:access(kala.objects.Object)
class CollisionShape extends BaseCollisionShape {
	
	public var type(default, null):ShapeType;
	public var dynamicPosition:Bool;
	public var absX(default, null):Null<FastFloat>;
	public var absY(default, null):Null<FastFloat>;
	
	override public function reset():Void {
		super.reset();
		dynamicPosition = true;
	}

	public inline function test(shape:CollisionShape):Bool {
		return switch(shape.type) {
			case ShapeType.CIRCLE: testCircle(cast shape);
			case ShapeType.RECTANGLE: testRect(cast shape);
		}
	}
	
	public function testCircle(circle:CollisionCircle):Bool {
		return false;
	}
	
	public function testRect(rect:CollisionRectangle):Bool {
		return false;
	}
	
	public function drawDebug(?fill:Bool = false, ?lineStrenght:FastFloat = 1, canvas:Canvas):Void {
		canvas.g2.transformation = Matrix.translation(absX, absY);
	}
	
	override function update(objectMatrix:Matrix):Void {
		var matrix:Matrix = (
			dynamicPosition ?
			objectMatrix.multmat(Matrix.translation(position.realX, position.realY)) :
			Matrix.translation(position.realX, position.realY).multmat(objectMatrix)
		);
		absX = matrix.tx;
		absY = matrix.ty;
	}
	
	override function get_available():Bool {
		return absX != null && absY != null;
	}
	
}