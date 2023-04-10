package entities;

import haxepunk.*;
import haxepunk.graphics.*;
import haxepunk.input.*;
import haxepunk.masks.*;
import haxepunk.math.*;
import haxepunk.Tween;
import haxepunk.tweens.misc.*;
import scenes.*;

class Player extends Entity
{
    public static inline var SPEED = 90;
    public static inline var GRAVITY = 690;
    public static inline var JUMP_POWER = 200 / 1.5 + 10;
    public static inline var DOUBLE_JUMP_POWER = JUMP_POWER;
    public static inline var JUMP_CANCEL = 30;
    public static inline var GRAVITY_MODIFIER_AT_PEAK = 0.5;
    public static inline var MAX_FALL_SPEED = 300;
    public static inline var COYOTE_TIME = 1 / 60 * 5;
    public static inline var JUMP_BUFFER_TIME = 1 / 60 * 5;
    public static inline var DASH_TIME = 1 / 60 * 9;
    public static inline var DASH_SPEED = 150 * 1.5;

    private var sprite:Spritemap;
    private var velocity:Vector2;
    private var timeOffGround:Float;
    private var timeJumpHeld:Float;
    private var dashTimer:Alarm;
    private var canDoubleJump:Bool;
    private var canceledJump:Bool;

    public function new(x:Float, y:Float) {
        super(x, y);
		mask = new Hitbox(6, 12, -1, 0);
        sprite = new Spritemap("graphics/player.png", 8, 12);
        sprite.add("idle", [0]);
        sprite.add("run", [1, 2, 3, 2], 8);
        sprite.add("jump", [4]);
        sprite.add("wall", [5]);
        sprite.add("skid", [6]);
        sprite.play("idle");
        graphic = sprite;
        mask = new Hitbox(6, 12, 1, 0);
        velocity = new Vector2();
        timeOffGround = 0;
        timeJumpHeld = 0;
        dashTimer = new Alarm(DASH_TIME);
        dashTimer.onComplete.bind(function() {
            velocity.x = 0;
            velocity.y = Math.max(velocity.y, -JUMP_CANCEL);
        });
        addTween(dashTimer);
        canDoubleJump = false;
        canceledJump = false;
    }

    override public function update() {
        if(Input.pressed("dash")) {
            dash();
        }
        if(dashTimer.active && Input.pressed("jump") && canDoubleJump) {
            dashTimer.active = false;
            canceledJump = true;
        }
        if(!dashTimer.active) {
            movement();
        }
        canceledJump = false;

        moveBy(
            velocity.x * HXP.elapsed,
            velocity.y * HXP.elapsed,
            ["walls"]
        );
        animation();
        super.update();
        if(Input.check("jump")) {
            timeJumpHeld += HXP.elapsed;
        }
        else {
            timeJumpHeld = 0;
        }
    }

    private function dash() {
        dashTimer.start();
        var heading = new Vector2();
        if(Input.check("left")) {
            heading.x = -1;
        }
        else if(Input.check("right")) {
            heading.x = 1;
        }

        if(Input.check("up")) {
            heading.y = -1;
        }
        else if(Input.check("down")) {
            heading.y = 1;
        }

        if(heading.length == 0) {
            heading.x = sprite.flipX ? -1 : 1;
        }

        velocity = heading;
        velocity.normalize(DASH_SPEED);
    }

    private function movement() {
        if(Input.check("left") && !isOnLeftWall()) {
            velocity.x = Math.min(velocity.x, -SPEED);
        }
        else if(Input.check("right") && !isOnRightWall()) {
            velocity.x = Math.max(velocity.x, SPEED);
        }
        else {
            velocity.x = 0;
        }

        if(isOnGround()) {
            timeOffGround = 0;
        }
        else {
            timeOffGround += HXP.elapsed;
        }

        if(isOnGround()) {
            velocity.y = 0;
            canDoubleJump = true;
        }
        else {
            if(Input.released("jump") && velocity.y < -JUMP_CANCEL) {
                velocity.y = -JUMP_CANCEL;
            }
        }

        if(isOnGround() || timeOffGround <= COYOTE_TIME) {
            if(
                Input.pressed("jump")
                || Input.check("jump") && timeJumpHeld <= JUMP_BUFFER_TIME
            ) {
                velocity.y = -JUMP_POWER;
            }
        }
        else if(!isOnGround() && canDoubleJump && Input.pressed("jump")) {
            if(canceledJump) {
                velocity.y = -DOUBLE_JUMP_POWER * 1.33;
            }
            else {
                velocity.y = -DOUBLE_JUMP_POWER;
            }
            canDoubleJump = false;
        }

        var decel = 300;
        if(velocity.x > SPEED) {
            velocity.x = MathUtil.approach(velocity.x, SPEED, decel * HXP.elapsed);
        }
        else if(velocity.x < -SPEED) {
            velocity.x = MathUtil.approach(velocity.x, -SPEED, decel * HXP.elapsed);
        }

        var gravity:Float = GRAVITY;
        if(Math.abs(velocity.y) < JUMP_CANCEL) {
            gravity *= GRAVITY_MODIFIER_AT_PEAK;
        }
        velocity.y += gravity * HXP.elapsed;

        velocity.y = Math.min(velocity.y, MAX_FALL_SPEED);
    }

    override public function moveCollideX(e:Entity) {
        velocity.x = 0;
        return true;
    }

    override public function moveCollideY(e:Entity) {
        velocity.y = 0;
        return true;
    }

    private function isOnGround() {
        return collide("walls", x, y + 1) != null;
    }

    private function isOnWall() {
        return isOnLeftWall() || isOnRightWall();
    }

    private function isOnLeftWall() {
        return collide("walls", x - 1, y) != null;
    }

    private function isOnRightWall() {
        return collide("walls", x + 1, y) != null;
    }

    private function animation() {
        sprite.color = dashTimer.active ? 0xFF000 : 0xFFFFFF;
        if(!isOnGround()) {
            sprite.play("jump");
            sprite.flipX = velocity.x < 0;
        }
        else if(velocity.x != 0) {
            if(
                velocity.x > 0 && Input.check("left")
                || velocity.x < 0 && Input.check("right")
            ) {
                sprite.play("skid");
            }
            else {
                sprite.play("run");
            }
            sprite.flipX = velocity.x < 0;
        }
        else {
            sprite.play("idle");
        }
    }
}
