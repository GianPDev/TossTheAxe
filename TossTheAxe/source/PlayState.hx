package;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUIState;
import flixel.addons.ui.FlxUISubState;
import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.input.FlxInput;
import flixel.input.mouse.FlxMouseEventManager;
import flixel.input.keyboard.FlxKey;
import flixel.addons.ui.ButtonLabelStyle;
import flixel.text.FlxText;
import flixel.addons.ui.BorderDef;
import flixel.input.gamepad.FlxGamepad;
import flixel.group.FlxGroup;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.util.FlxColor;
import flixel.system.FlxSound;
import flixel.util.FlxTimer;

import flixel.addons.nape.*;
import nape.geom.Vec2;
import nape.phys.Body;
import nape.phys.BodyType;
import nape.shape.Polygon;
import nape.space.Space;
import nape.shape.Circle;
import nape.constraint.PivotJoint;
import nape.constraint.AngleJoint;
import nape.constraint.DistanceJoint;
import nape.constraint.LineJoint;
import nape.callbacks.CbEvent;
import nape.callbacks.CbType;
import nape.callbacks.InteractionCallback;
import nape.callbacks.InteractionListener;
import nape.callbacks.InteractionType;
import nape.dynamics.InteractionFilter;

#if (mobile)
import flixel.input.FlxAccelerometer;
#end

class PlayState extends FlxUIState
{	
	public var uiCamera:FlxCamera;
	var gameCamera:FlxCamera;

	var btnHovering:Bool = false;
	var resetState:FlxUIButton;

	public var closedCaptions:FlxText;

	public var hand:PivotJoint;
	var nSprAxe:FlxNapeSprite;

	public var CB_TARGET:CbType = new CbType();
	public var CB_AXEHEAD:CbType = new CbType();
	public var CB_WALL:CbType = new CbType();
	public var CB_HANDLE:CbType = new CbType();

	public var pin:PivotJoint;

	public var groupTargets:FlxTypedGroup<FlxNapeSprite>;

	var sndHit:FlxSound;
	var sndWallHit:FlxSound;
	var sndHandleHit:FlxSound;

	var score:Int = 0;

	public var piercing:Bool = false;

	var slowUpdate:FlxTimer;

	#if (mobile)
	var accelerometer:FlxAccelerometer;
	#end
	var sensitivity:Float;

	override public function create():Void
	{
		//FlxG.plugins.add(new FlxMouseEventManager());
		#if (mobile)
		accelerometer = new FlxAccelerometer();
		#end

		if(Main.tongue == null)
		{
			Main.tongue = new FireTongueEx();
			Main.tongue.init("en-US");
			FlxUIState.static_tongue = Main.tongue; //IMPORTANT Must change before it is created, as static variables cannot be changed after created?
		}

		gameCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		gameCamera.bgColor = 0xff4D5959;

		uiCamera = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		uiCamera.bgColor = FlxColor.TRANSPARENT;
		
		FlxG.cameras.reset(gameCamera);
		FlxG.cameras.add(uiCamera);

		FlxCamera.defaultCameras = [gameCamera];
		
		super.create();

		FlxG.worldBounds.set(0, 0, Math.floor(FlxG.width + FlxG.width / 2), FlxG.height * 2);
		FlxG.camera.setScrollBoundsRect(0, 0, Math.floor(FlxG.width + FlxG.width / 2) + 50, FlxG.height * 2, false);
		//FlxG.camera.zoom = 1.5;

		groupTargets = new FlxTypedGroup();

		sndHit = FlxG.sound.load("assets/sounds/hit001.wav");
		sndWallHit = FlxG.sound.load("assets/sounds/hit002.wav");
		sndHandleHit = FlxG.sound.load("assets/sounds/hit003.wav");

		closedCaptions = new FlxText(16, FlxG.height - 128, FlxG.width, "", 8, false);
		closedCaptions.cameras = [uiCamera];
		closedCaptions.setFormat(null, 8, 0xFFFFFFFF, CENTER, OUTLINE_FAST, 0xFF000000, false);
		closedCaptions.text = "Toss The Axe" + " by " + "Gian P.";
		closedCaptions.size = 16;
		add(closedCaptions);

		resetState = new FlxUIButton(0, 0, _tongue.get("$RESET", "ui"));
		resetState.loadGraphicSlice9(null, 0, 0, null, FlxUI9SliceSprite.TILE_NONE, -1, true);
		resetState.name = "resetState";
		resetState.params = [0, "reset"];
		resetState.resize(25, 25);
		resetState.getLabel().text = _tongue.get("$RESET", "ui");
		resetState.getLabel().size = 16;
		resetState.getLabel().color = 0xFFEEEEEE;
		resetState.color = 0xFFAA0000;
		//add(resetState);
	

		FlxNapeSpace.init(); //creates a nape space for nape items to do physics in
		FlxNapeSpace.drawDebug = true;
		FlxNapeSpace.space.gravity.setxy(0, 1000);

		var nDownWall:FlxNapeSprite = new FlxNapeSprite(0, 0);
		nDownWall.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nDownWall.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nDownWall.body = new Body(BodyType.KINEMATIC); //makes a new body and sets it to the sprite's body, in this case it's a static one (not affected by physics) - a container?
		var shapeDownWall:Polygon = new Polygon(Polygon.box(Math.floor(FlxG.width + FlxG.width / 2), 50));
		//shapeDownWall.filter.collisionMask = 1;
		nDownWall.body.shapes.add(shapeDownWall);
		nDownWall.setPosition(Math.floor(FlxG.width + FlxG.width / 2) / 2, FlxG.height * 2);
		nDownWall.makeGraphic(Math.floor(FlxG.width + FlxG.width / 2), 50, 0xFF404C4D);
		shapeDownWall.cbTypes.add(CB_WALL);
		nDownWall.body.space = FlxNapeSpace.space;
		add(nDownWall);

		var nUpWall:FlxNapeSprite = new FlxNapeSprite(0, 0);
		nUpWall.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nUpWall.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nUpWall.body = new Body(BodyType.KINEMATIC); //makes a new body and sets it to the sprite's body, in this case it's a KINEMATIC one (not affected by physics) - a container?
		var shapeUpWall:Polygon = new Polygon(Polygon.box(Math.floor(FlxG.width + FlxG.width / 2), 50));
		//shapeDownWall.filter.collisionMask = 1;
		nUpWall.body.shapes.add(shapeUpWall);
		nUpWall.setPosition(Math.floor(FlxG.width + FlxG.width / 2) / 2, 0);
		nUpWall.makeGraphic(Math.floor(FlxG.width + FlxG.width / 2), 50, 0xFF404C4D);
		shapeUpWall.cbTypes.add(CB_WALL);
		nUpWall.body.space = FlxNapeSpace.space;
		add(nUpWall);

		var nLeftWall:FlxNapeSprite = new FlxNapeSprite(0, 0);
		nLeftWall.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nLeftWall.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nLeftWall.body = new Body(BodyType.KINEMATIC); //makes a new body and sets it to the sprite's body, in this case it's a KINEMATIC one (not affected by physics) - a container?
		var shapeLeftWall:Polygon = new Polygon(Polygon.box(50, FlxG.height * 2));
		//shapeDownWall.filter.collisionMask = 1;
		nLeftWall.body.shapes.add(shapeLeftWall);
		nLeftWall.setPosition(0, FlxG.height * 2 / 2);
		nLeftWall.makeGraphic(50, FlxG.height * 2, 0xFF404C4D);
		shapeLeftWall.cbTypes.add(CB_WALL);
		nLeftWall.body.space = FlxNapeSpace.space;
		add(nLeftWall);

		var nRightWall:FlxNapeSprite = new FlxNapeSprite(0, 0);
		nRightWall.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nRightWall.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nRightWall.body = new Body(BodyType.KINEMATIC); //makes a new body and sets it to the sprite's body, in this case it's a KINEMATIC one (not affected by physics) - a container?
		var shapeRightWall:Polygon = new Polygon(Polygon.box(50, FlxG.height * 2));
		//hapeDownWall.filter.collisionMask = 1;
		nRightWall.body.shapes.add(shapeRightWall);
		nRightWall.setPosition(Math.floor(FlxG.width + FlxG.width / 2), FlxG.height * 2 / 2);
		nRightWall.makeGraphic(50, FlxG.height * 2, 0xFF404C4D);
		shapeRightWall.cbTypes.add(CB_WALL);
		nRightWall.body.space = FlxNapeSpace.space;
		add(nRightWall);
		
		/*
		var bodyWalls:Body = new Body(BodyType.STATIC);
		bodyWalls.shapes.add(new Polygon(Polygon.rect(20, 0, -40, FlxG.height))); //creates left wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(Math.floor(FlxG.width - 20), 0, 40, FlxG.height))); //creats right wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(0, 20, FlxG.width, -40))); //creates top wall
		bodyWalls.shapes.add(new Polygon(Polygon.rect(0, Math.floor(FlxG.height - 20), FlxG.width, 40))); //create bottom wall
		bodyWalls.space = FlxNapeSpace.space;
		*/
		//PivotJoint which is used to drag stuff using mouse.
		hand = new PivotJoint(FlxNapeSpace.space.world, FlxNapeSpace.space.world, new Vec2(), new Vec2());
		hand.stiff = false;
		hand.space = FlxNapeSpace.space;
		hand.active = false;

		pin = new PivotJoint(FlxNapeSpace.space.world, null, new Vec2(0,0), new Vec2(0,0));
		pin.active = false;
		pin.stiff = false;


		nSprAxe = new FlxNapeSprite(0, 0);
		nSprAxe.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nSprAxe.loadGraphic("assets/images/axe.png", false, 100, 200);
		nSprAxe.setGraphicSize(100, 200);
		nSprAxe.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nSprAxe.body = new Body(BodyType.DYNAMIC); //makes a new body and sets it to the sprite's body, in this case it's a static one (not affected by physics) - a container?
		var handleShape:Polygon = new Polygon(Polygon.box(25, 200));
		handleShape.filter.collisionGroup = 1;
		handleShape.filter.collisionMask = 1;
		handleShape.cbTypes.add(CB_HANDLE);
		nSprAxe.body.shapes.add(handleShape);
		var axeShape:Polygon = new Polygon(Polygon.regular(50, 64, 6)); //The actual physics body shape that does physics with other objects
		axeShape.filter.collisionMask = 1;
		axeShape.sensorEnabled = false;
		axeShape.filter.sensorGroup = 2;
		nSprAxe.body.userData.data = nSprAxe;
		axeShape.cbTypes.add(CB_AXEHEAD);
		nSprAxe.body.shapes.add(axeShape);
		var endHandle:Circle = new Circle(75);
		endHandle.filter.collisionMask = 0;
		nSprAxe.body.shapes.add(endHandle);
		trace("shapes: " + nSprAxe.body.shapes);
		//shapes are shifted instead of pushed into an array
		nSprAxe.body.shapes.at(0).translate(new Vec2(0, 75)); 
		nSprAxe.body.shapes.at(1).translate(new Vec2(0, -50)); 
		nSprAxe.body.shapes.at(2).translate(new Vec2(0, 0)); 
		nSprAxe.setPosition(Math.floor(FlxG.width + FlxG.width / 2) / 2, FlxG.height * 2/2);
		nSprAxe.body.space = FlxNapeSpace.space;
		add(nSprAxe);
		trace(nSprAxe);

		/*
		nSprAxe = new FlxNapeSprite(0, 0);
		nSprAxe.destroyPhysObjects(); //destroyting exisiting nape stuff to add our own nape stuff
		nSprAxe.loadGraphic("assets/images/axe.png", false, 50, 100);
		nSprAxe.setGraphicSize(50, 100);
		nSprAxe.centerOffsets(false); //not sure what this does, it was part of a function I copied
		nSprAxe.body = new Body(BodyType.DYNAMIC); //makes a new body and sets it to the sprite's body, in this case it's a static one (not affected by physics) - a container?
		var handleShape:Polygon = new Polygon(Polygon.box(5, 50));
		handleShape.filter.collisionMask = 1;
		nSprAxe.body.shapes.add(handleShape);
		var axeShape:Polygon = new Polygon(Polygon.regular(26, 32, 6)); //The actual physics body shape that does physics with other objects
		axeShape.filter.collisionMask = 1;
		nSprAxe.body.shapes.add(axeShape);
		trace("shapes: " + nSprAxe.body.shapes);
		nSprAxe.body.shapes.at(0).translate(new Vec2(0, -25)); //axe head
		nSprAxe.body.shapes.at(1).translate(new Vec2(0, 25)); //handle
		nSprAxe.setPosition(FlxG.width / 2, FlxG.height/2);
		nSprAxe.body.space = FlxNapeSpace.space;
		add(nSprAxe);
		trace(nSprAxe);
		*/

		for (i in 0...10) 
		{
			var nSprCircle:FlxNapeSprite = new FlxNapeSprite(0, 0);
			nSprCircle.destroyPhysObjects();
			nSprCircle.centerOffsets(false);
			nSprCircle.body = new Body(BodyType.KINEMATIC);
			nSprCircle.setPosition(FlxG.random.int(100, Math.floor(FlxG.width + FlxG.width / 4 - 100)), FlxG.random.int(150, Math.floor(FlxG.height + (FlxG.height / 6))));
			var circleShape:Circle = new Circle(50);
			circleShape.filter.collisionGroup = 1;
			//circleShape.sensorEnabled = true;
			circleShape.filter.sensorGroup = 2;
			nSprCircle.body.shapes.add(circleShape);
			nSprCircle.makeGraphic(100, 100, 0xFFFF0000);
			nSprCircle.loadGraphic("assets/images/target.png");
			nSprCircle.body.userData.data = nSprCircle;
			nSprCircle.body.cbTypes.add(CB_TARGET);
			nSprCircle.body.space = FlxNapeSpace.space;
			groupTargets.add(nSprCircle);
			add(nSprCircle);

		}

		FlxG.camera.follow(nSprAxe, FlxCameraFollowStyle.PLATFORMER);
		FlxG.camera.zoom = 0.8;

		FlxNapeSpace.space.listeners.add(new InteractionListener(
			CbEvent.BEGIN,
			InteractionType.SENSOR,
			CB_AXEHEAD,
			CB_TARGET,
			onTargetCollide
		));
		FlxNapeSpace.space.listeners.add(new InteractionListener(
			CbEvent.BEGIN,
			InteractionType.COLLISION,
			CB_AXEHEAD,
			CB_TARGET,
			onTargetCollide
		));
		FlxNapeSpace.space.listeners.add(new InteractionListener(
			CbEvent.BEGIN,
			InteractionType.COLLISION,
			CB_AXEHEAD,
			CB_WALL,
			onWallCollide
		));
		FlxNapeSpace.space.listeners.add(new InteractionListener(
			CbEvent.BEGIN,
			InteractionType.COLLISION,
			CB_HANDLE,
			CbType.ANY_BODY,
			onHandleCollide
		));

		trace(FlxNapeSpace.space.listeners);
		//make game infinitely scroll upwards, but make it be able to go back down, or maybe just make it massive. 
		//just made it massive.
		
		/* Code for adding accelerometer to control gravity
		#if(mobile)
		sensitivity = 0.09;
		var sensUp:FlxUIButton = new FlxUIButton(FlxG.width / 2 + 25, 0, "+");
		sensUp.loadGraphicSlice9(null, 0, 0, null, FlxUI9SliceSprite.TILE_NONE, -1, true);
		sensUp.name = "sensUp";
		sensUp.params = [0, "sensUp"];
		sensUp.resize(50, 50);
		sensUp.getLabel().size = 16;
		sensUp.getLabel().color = 0xFFEEEEEE;
		sensUp.color = 0xFFAA0000;
		//add(sensUp);
		
		var sensDown:FlxUIButton = new FlxUIButton(FlxG.width / 2 - 25, 0, "-");
		sensDown.loadGraphicSlice9(null, 0, 0, null, FlxUI9SliceSprite.TILE_NONE, -1, true);
		sensDown.name = "sensDown";
		sensDown.params = [0, "sensDown"];
		sensDown.resize(50, 50);
		sensDown.getLabel().size = 16;
		sensDown.getLabel().color = 0xFFEEEEEE;
		sensDown.color = 0xFFAA0000;
		//add(sensDown);
		
		slowUpdate = new FlxTimer().start(0.3, function(_)
		{
			// if(accelerometer.x > sensitivity || accelerometer.x < -sensitivity)
			// 	FlxNapeSpace.space.gravity.x = Math.floor(accelerometer.x * 10000);
			// else
			// 	FlxNapeSpace.space.gravity.setxy(0, 0);
			// if(accelerometer.y > (sensitivity / 2) || accelerometer.y < (-sensitivity / 2))
			// 	FlxNapeSpace.space.gravity.y = Math.floor(accelerometer.y * 2 * 10000);
			// else
			// 	FlxNapeSpace.space.gravity.setxy(0, 0);

			FlxNapeSpace.space.gravity.setxy(Math.floor(accelerometer.x * 10000), Math.floor(accelerometer.y * 2 * 10000));

			setCaptions(
			"slowUpdate Time: " + Std.string(slowUpdate.elapsedLoops) + 
			//"\nSensitivity: " + sensitivity + ", " + (sensitivity / 2) +
			"\nGravity: " + Std.string(FlxNapeSpace.space.gravity.x) + ", " + Std.string(FlxNapeSpace.space.gravity.y) +
			"\nAccelerometer: " + Std.string(accelerometer.x) + ", " + Std.string(accelerometer.y));
		}, 0);
		#end

		*/
	}
	
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		
		/*
		#if (mobile)
		
		if(accelerometer.x > sensitivity || accelerometer.x < -sensitivity)
			FlxNapeSpace.space.gravity.x = Math.floor(accelerometer.x * 10000);
		else
			FlxNapeSpace.space.gravity.setxy(0, 0);
		if(accelerometer.y > (sensitivity / 2) || accelerometer.y < (-sensitivity / 2))
			FlxNapeSpace.space.gravity.y = Math.floor(accelerometer.y * 2 * 10000);
		else
			FlxNapeSpace.space.gravity.setxy(0, 0);

		setCaptions(
		"Sensitivity: " + sensitivity + ", " + (sensitivity / 2) +
		"\nGravity: " + Std.string(FlxNapeSpace.space.gravity.x) + ", " + Std.string(FlxNapeSpace.space.gravity.y) +
		"\nAccelerometer: " + Std.string(accelerometer.x) + ", " + Std.string(accelerometer.y));
		#end
		*/

		if(FlxG.keys.anyJustPressed(["SPACE"]))
		{
			if(piercing)
			{
				piercing = false;
				nSprAxe.body.shapes.at(1).filter.collisionMask = 1;
				nSprAxe.body.shapes.at(1).sensorEnabled = false;
			}

			else
			{
				piercing = true;
				nSprAxe.body.shapes.at(1).filter.collisionMask = 0;
				nSprAxe.body.shapes.at(1).sensorEnabled = true;
			}

			setCaptions("piercing: " + Std.string(piercing)); 
		}

		hand.anchor1.setxy(FlxG.mouse.x, FlxG.mouse.y);
		if(FlxG.mouse.justPressed)
		{
			//setCaptions("Left Clicked");
			var mp:Vec2 = new Vec2(FlxG.mouse.x, FlxG.mouse.y);
			for(i in 0...FlxNapeSpace.space.bodiesUnderPoint(mp).length)
			{
				var b:Body = FlxNapeSpace.space.bodiesUnderPoint(mp).at(i);
				if(!b.isDynamic()) continue;
					hand.body2 = b;
					hand.anchor2 = b.worldPointToLocal(mp);
					hand.active = true;
					FlxG.camera.target = null;
					FlxG.camera.zoom = 0.8;
					/*
					pin.body1 = FlxNapeSpace.space.world;
					pin.body2 = b; 
					pin.anchor1 = new Vec2(b.position.x, b.position.y + 50);
					pin.anchor2 = new Vec2(0,0);
					pin.active = true;
					pin.space = FlxNapeSpace.space;
					*/
				break;
			}
		}
		else if (FlxG.mouse.justReleased)
		{
			hand.active = false;

			FlxG.camera.follow(nSprAxe, FlxCameraFollowStyle.PLATFORMER);
			FlxG.camera.zoom = 0.8;
			//pin.active = false;
		}

		if(closedCaptions.alpha > 0) //if statement for constantly fading out text every frame
		{
			closedCaptions.alpha -= .005;
		}

	}

	//overriding the getEvent function is for the FlxUIButtons and maybe other FlxUI stuff.
	public override function getEvent(event:String, target:Dynamic, data:Dynamic, ?params:Array<Dynamic>):Void
	{
		if (params != null)
		{
			switch (event)
			{
				case "over_button":  btnHovering = true; trace("Button Hovering: " + btnHovering);
					switch(Std.string(params[1]))
					{
						case "toggle": "";
					}
				case "down_button": //a button is "down" when it is clicked, it does not have to be released on button
					switch(Std.string(params[1]))
					{
						case "rebind"	: "";
						case "up"		: "";
						case "down"		: "";
						case "left"		: "";
						case "right"	: "";
					}
				case "click_button": //click button and down button should be switched imo - click button is "clicked" when it is clicked and released over the button
					switch(Std.string(params[1]))
					{
						case "toggle" : "";
						case "reset": FlxG.resetState();
						case "sensUp":
							if(sensitivity <= 1) 
								sensitivity += 0.01;
							trace("Sensitvity: " + sensitivity);
							setCaptions("Sensitivity: " + sensitivity);
						case "sensDown": 
							if(sensitivity >= 0.01) 
								sensitivity -= 0.01;
							trace("Sensitvity: " + sensitivity);
							setCaptions("Sensitivity: " + sensitivity);
					}
				case "out_button": btnHovering = false; trace("Button Hovering: " + btnHovering); //When mouse is moved off from being over the button i.e Mouse that was over the button is no longer over that button
					switch (Std.string(params[1]))
					{
						case "toggle": "";
					}
				
			}
		}
	}

	function setCaptions(text:String):Void
	{
		closedCaptions.text = text;
		closedCaptions.alpha = 1;
	}

	function onWallCollide(cb:InteractionCallback):Void
	{
		sndWallHit.play(true);

	}
	function onHandleCollide(cb:InteractionCallback):Void
	{
		sndHandleHit.play(true);

	}

	function onTargetCollide(cb:InteractionCallback):Void
	{
		trace(cb.int1);
		trace(cb.int2);
		
		var b:FlxNapeSprite = cast(cb.int2, Body).userData.data;

		sndHit.play(true);
		score++;
		setCaptions("Targets: " + Std.string(score));
		if(b != null)
		{
			b.kill();
			b.exists = false;

			var sprite:FlxNapeSprite = groupTargets.recycle();
			trace(sprite);
			sprite.setPosition(FlxG.random.int(100, Math.floor(FlxG.width + FlxG.width / 4 - 100)), FlxG.random.int(150, Math.floor(FlxG.height + (FlxG.height / 6))));
			/*
			//Creates Circle
			var nSprCircle:FlxNapeSprite = new FlxNapeSprite(0, 0);
			nSprCircle.destroyPhysObjects();
			nSprCircle.centerOffsets(false);
			nSprCircle.body = new Body(BodyType.KINEMATIC);
			nSprCircle.body.position.setxy(Math.random() * FlxG.width, Math.random() * (FlxG.height * 2));
			while(nSprCircle.body.position.y > FlxG.height + FlxG.height / 4 || nSprCircle.body.position.x < 25 || nSprCircle.body.position.x > FlxG.width - 25)
			{
				nSprCircle.body.position.y = Math.random() * FlxG.height;
				nSprCircle.body.position.x = Math.random() * FlxG.width;
			}
			var circleShape:Circle = new Circle(50);
			circleShape.filter.collisionGroup = 1;
			circleShape.filter.sensorMask = 1;
			nSprCircle.body.shapes.add(circleShape);
			nSprCircle.loadGraphic("assets/images/target.png");
			nSprCircle.body.userData.data = nSprCircle;
			nSprCircle.body.cbTypes.add(CB_TARGET);
			nSprCircle.body.space = FlxNapeSpace.space;
			add(nSprCircle);
			*/
		}
		else
			trace("b is null");
	}
}
