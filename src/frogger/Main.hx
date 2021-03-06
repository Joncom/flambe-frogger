package frogger;

import flambe.Entity;
import flambe.System;
import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.FillSprite;
import flambe.display.ImageSprite;
import flambe.display.TextSprite;
import flambe.display.Font;
import flambe.script.Script;
import flambe.script.Repeat;
import flambe.script.Sequence;
import flambe.script.MoveTo;
import flambe.script.CallFunction;

import flambe.swf.Library;
import flambe.swf.MovieSprite;
import flambe.input.KeyboardEvent;
import flambe.input.Key;

class Main
{
    // Constants
    private static inline var LANE_COUNT:Int = 4;
    private static inline var LANE_WIDTH:Int = 13;
    private static inline var TILESIZE:Int = 64;

    private static var score:Int;
    private static var font:Font;

    private static var STATE_UP:Bool = false;
    private static var STATE_DOWN:Bool = false;
    private static var STATE_LEFT:Bool = false;
    private static var STATE_RIGHT:Bool = false;
    private static var PRESSED_UP:Bool = false;
    private static var PRESSED_DOWN:Bool = false;
    private static var PRESSED_LEFT:Bool = false;
    private static var PRESSED_RIGHT:Bool = false;

    private static var frog:Entity;
    private static var frogSprite:MovieSprite;
    private static var frogLastCarTouched:Int;
    private static var frogLastGrassHitboxTouched:Entity;
    private static var frogKilledAt:Float;
    private static var frogDefaultX:Float;
    private static var frogDefaultY:Float;

    private static var frogIdle:MovieSprite;
    private static var frogHop:MovieSprite;
    private static var frogKilled:MovieSprite;

    private static var road:Entity;
    private static var grass:Entity;

    private static var topGrassHitbox:Entity;
    private static var bottomGrassHitbox:Entity;

    private static var defaultCarSpeed:Int = 25;
    private static var carSpeed:Int;
    private static var laneSpeedFactor:Array<Int> = [4, 3, 6, 2, 5];

    private static var cars:Array<Car> = [];

    public static var pack:AssetPack;

    private static var lastFrame:Float = 0;

    private static var scoreText:TextSprite;
    private static var gameOverText:TextSprite;

    private static function main ()
    {
        // Wind up all platform-specific stuff
        System.init();

        // Load up the compiled pack in the assets directory named "bootstrap"
        var manifest = Manifest.fromAssets("bootstrap");
        var loader = System.loadAssetPack(manifest);
        loader.get(onSuccess);
    }

    private static function onSuccess (pack :AssetPack)
    {
        lastFrame = Date.now().getTime();
        font = new Font(pack, "font");
        score = 0;
        carSpeed = defaultCarSpeed;

        Main.pack = pack;

        // Construct road
        road = new Entity();
        for(y in 1...LANE_COUNT+1) {
            for(x in 0...LANE_WIDTH) {
                var tile = new ImageSprite(pack.getTexture("road-tile"));
                tile.x._ = x * TILESIZE;
                tile.y._ = y * TILESIZE;
                road.addChild(new Entity().add(tile));
            }
        }
        System.root.addChild(road);

        // Construct grass
        grass = new Entity();
        for(y in [0,LANE_COUNT+1]) {
            for(x in 0...LANE_WIDTH) {
                var tile = new ImageSprite(pack.getTexture("grass-tile"));
                tile.x._ = x * TILESIZE;
                tile.y._ = y * TILESIZE;
                tile.scaleX._ = 2;
                tile.scaleY._ = 2;
                grass.addChild(new Entity().add(tile));
            }
        }
        System.root.addChild(grass);

        // Setup main update loop
        var script:Script = new Script();
        script.run(new Repeat(new CallFunction(update), -1));
        System.root.add(script);

        scoreText = new TextSprite(font, "" + score);
        scoreText.centerAnchor();
        scoreText.x._ = (LANE_WIDTH * TILESIZE) / 2;
        scoreText.y._ = TILESIZE / 2 + TILESIZE * 2;
        System.root.addChild(new Entity().add(scoreText));

        gameOverText = new TextSprite(font, "GAME OVER");
        gameOverText.centerAnchor();
        gameOverText.x._ = (LANE_WIDTH * TILESIZE) / 2;
        gameOverText.y._ = TILESIZE / 2 + TILESIZE * 3;
        gameOverText.alpha._ = 0;
        System.root.addChild(new Entity().add(gameOverText));

        frog = new Entity();

        var lib = new Library(pack, "frog");
        frogIdle = lib.createMovie("Frog.Idle", true);
        frogHop = lib.createMovie("Frog.Hop", true);
        frogKilled = lib.createMovie("Frog.Killed", true);
        
        for(sprite in [frogIdle, frogHop, frogKilled]) {
            sprite.scaleX._ = 0.5;
            sprite.scaleY._ = 0.5;
        }

        frogDefaultX = TILESIZE/2 + Math.floor(LANE_WIDTH / 2) * TILESIZE;
        frogDefaultY = TILESIZE/2 + (LANE_COUNT + 1) * TILESIZE;

        frogSprite = frogIdle;
        frogSprite.x._ = frogDefaultX;
        frogSprite.y._ = frogDefaultY;

        frog.add(frogSprite);
        System.root.addChild(frog);

        System.keyboard.down.connect(function(event:KeyboardEvent) {
            PRESSED_UP = STATE_UP = event.key == Key.Up;
            PRESSED_DOWN = STATE_DOWN = event.key == Key.Down;
            PRESSED_LEFT = STATE_LEFT = event.key == Key.Left;
            PRESSED_RIGHT = STATE_RIGHT = event.key == Key.Right;
        });

        System.keyboard.up.connect(function(event:KeyboardEvent) {
            STATE_UP = !(event.key == Key.Up);
            STATE_DOWN = !(event.key == Key.Down);
            STATE_LEFT = !(event.key == Key.Left);
            STATE_RIGHT = !(event.key == Key.Right);
        });

        // Add one car to each lane
        for(lane in 0...LANE_COUNT) {
            addCar(lane);
        }

        // Setup grass hitboxes for registering points
        topGrassHitbox = new Entity().add(new FillSprite(0x000000, LANE_WIDTH * TILESIZE, TILESIZE));
        bottomGrassHitbox = new Entity().add(new FillSprite(0x000000, LANE_WIDTH * TILESIZE, TILESIZE));
        bottomGrassHitbox.get(FillSprite).y._ = (LANE_COUNT + 1) * TILESIZE;

        // Prevent frog from getting a free point
        frogLastGrassHitboxTouched = bottomGrassHitbox;
    }

    private static function update() {
        // Calculate delta since last frame
        var now = Date.now().getTime();
        var dt = (now - lastFrame)/1000;
        lastFrame = now;

        // Remove old cars
        if(cars.length > 0) {
            var i = cars.length - 1;
            while(i >= 0) {
                var sprite = cars[i].entity.get(ImageSprite);
                if(
                    (cars[i].direction == 'RIGHT' && sprite.x._ - sprite.getNaturalWidth()/2 >= LANE_WIDTH * TILESIZE) ||
                    (cars[i].direction == 'LEFT' && sprite.x._ + sprite.getNaturalWidth()/2 <= -sprite.getNaturalWidth())
                ) {
                    System.root.removeChild(cars[i].entity);
                    cars.splice(i, 1);
                }
                i--;
            }
        }

        // Spawn new cars
        var y = TILESIZE;
        for(i in 0...cars.length) {
            var car = cars[i];
            if(!car.nextCarSpawned) {
                var sprite = car.entity.get(ImageSprite);
                if(
                    (car.direction == 'RIGHT' && sprite.x._ >= car.gap) || 
                    (car.direction == 'LEFT' && sprite.x._ + sprite.getNaturalWidth() <= LANE_WIDTH * TILESIZE - car.gap)
                ) {
                    addCar(car.lane);
                    car.nextCarSpawned = true;
                }
            }
        }

        // Move cars
        for(car in cars) {
            var speed = carSpeed * laneSpeedFactor[car.lane];
            car.entity.get(ImageSprite).x._ += speed * dt * (car.direction == 'LEFT' ? -1 : 1);
        }

        // Kill frog when he collides with car
        if(frogSprite != frogKilled) {
            for(car in cars) {
                if(car.entity.get(ImageSprite).contains(frogSprite.x._, frogSprite.y._)) {
                    frogKilled.x._ = frogSprite.x._;
                    frogKilled.y._ = frogSprite.y._;
                    frogKilled.rotation._ = frogSprite.rotation._;
                    frog.remove(frogSprite);
                    frog.add(frogKilled);
                    frogSprite = frogKilled;

                    pack.getSound("hit").play();

                    // Frog may be moving, if so remove that script to stop him
                    var script = frog.get(Script);
                    frog.remove(script);

                    // Show game over text
                    gameOverText.alpha.animateTo(1, 0.125);

                    frogKilledAt = now;

                    // Play death animation and then pause at the end
                    frogKilled.position = 0;
                    frogKilled.onUpdate(0);
                    frogKilled.paused = false;
                    frogKilled.looped.connect(function() {
                        frogKilled.position = frogKilled.symbol.duration;
                        frogKilled.onUpdate(0);
                        frogKilled.paused = true;
                    }).once();
                    break;
                }
            }
        }

        // Let cars continue to trample frog
        if(frogSprite == frogKilled) {
            for(car in cars) {
                if(car.entity.get(ImageSprite).contains(frogSprite.x._, frogSprite.y._)) {
                    if(frogLastCarTouched != car.id) {
                        frogLastCarTouched = car.id;
                        pack.getSound("hit").play();

                        // Play death animation and then pause at the end
                        frogKilled.position = 0;
                        frogKilled.onUpdate(0);
                        frogKilled.paused = false;
                        frogKilled.looped.connect(function() {
                            frogKilled.position = frogKilled.symbol.duration;
                            frogKilled.onUpdate(0);
                            frogKilled.paused = true;
                        }).once();
                        break;
                    }
                }
            }
        }

        // Handle frog jumping
        if(frogSprite == frogIdle) {
            var moveX = 0;
            var moveY = 0;
            var minX = TILESIZE/2;
            var minY = TILESIZE/2;
            var maxX = TILESIZE/2 + (LANE_WIDTH - 1) * TILESIZE;
            var maxY = TILESIZE/2 + (LANE_COUNT + 1) * TILESIZE;
            if(PRESSED_DOWN && frogSprite.y._ < maxY) {
                moveY = TILESIZE;
            } else if(PRESSED_UP && frogSprite.y._ > minY) {
                moveY = -TILESIZE;
            } else if(PRESSED_LEFT && frogSprite.x._ > minX) {
                moveX = -TILESIZE;
            } else if(PRESSED_RIGHT && frogSprite.x._ < maxX) {
                moveX = TILESIZE;
            }
            if(moveX != 0 || moveY != 0) {
                // Swap in new animation
                frogHop.x._ = frogIdle.x._;
                frogHop.y._ = frogIdle.y._;
                frogHop.rotation._ = frogIdle.rotation._;
                frog.remove(frogIdle);
                frog.add(frogHop);
                frogSprite = frogHop;

                // Set rotation
                if(moveX > 0) {
                    frogSprite.rotation._ = 90;
                } else if(moveX < 0) {
                    frogSprite.rotation._ = -90;
                } else if(moveY > 0) {
                    frogSprite.rotation._ = 180;
                } else if(moveY < 0) {
                    frogSprite.rotation._ = 0;
                }

                // Move
                var script:Script = new Script();
                script.run(new Sequence([
                    new MoveTo(frogHop.x._ + moveX, frogHop.y._ + moveY, frogHop.symbol.duration),
                    new CallFunction(function(){
                        // Return to idle state
                        frogIdle.x._ = frogHop.x._;
                        frogIdle.y._ = frogHop.y._;
                        frogIdle.rotation._ = frogHop.rotation._;
                        frog.remove(frogHop);
                        frog.add(frogIdle);
                        frogSprite = frogIdle;
                    })
                ]));
                frog.add(script);

                pack.getSound("jump").play();

                // Play frog hop animation and then pause once done
                frogHop.position = 0;
                frogHop.onUpdate(0);
                frogHop.paused = false;
                frogHop.looped.connect(function() {
                    frogHop.position = frogHop.symbol.duration;
                    frogHop.onUpdate(0);
                    frogHop.paused = true;
                }).once();
            }
        }

        // Award point for touching grass
        if(frogSprite != frogKilled) {
            for(grassHitbox in [topGrassHitbox, bottomGrassHitbox]) {
                if(grassHitbox.get(FillSprite).contains(frogSprite.x._, frogSprite.y._)) {
                    if(frogLastGrassHitboxTouched != grassHitbox) {
                        frogLastGrassHitboxTouched = grassHitbox;
                        score++;
                        scoreText.text = "" + score;
                        scoreText.scaleX._ = 0;
                        scoreText.scaleY._ = 0;
                        scoreText.alpha._ = 0;
                        scoreText.scaleX.animateTo(1, 0.25);
                        scoreText.scaleY.animateTo(1, 0.25);
                        scoreText.alpha.animateTo(1, 0.25);
                        pack.getSound("achieve").play();
                        carSpeed += 6;
                        trace('point');
                    }
                }
            }
        }

        // Handle respawn
        if(frogSprite == frogKilled && now - frogKilledAt > 1000) {
            if(PRESSED_UP || PRESSED_DOWN || PRESSED_LEFT || PRESSED_RIGHT) {
                // Return to default state
                frogIdle.x._ = frogDefaultX;
                frogIdle.y._ = frogDefaultY;
                frogIdle.rotation._ = frogKilled.rotation._;
                frog.remove(frogKilled);
                frog.add(frogIdle);
                frogSprite = frogIdle;
                gameOverText.alpha._ = 0;
                score = 0;
                scoreText.text = "" + score;
                carSpeed = defaultCarSpeed;
                frogLastGrassHitboxTouched = bottomGrassHitbox; // prevent free point
            }
        }

        // Clear presses
        PRESSED_UP = false;
        PRESSED_DOWN = false;
        PRESSED_LEFT = false;
        PRESSED_RIGHT = false;
    }

    private static function addCar(lane) {
        var car = new Car();
        var sprite = car.entity.get(ImageSprite);

        sprite.x._ = (lane % 2 == 0 ? -sprite.getNaturalWidth()/2 : LANE_WIDTH * TILESIZE + sprite.getNaturalWidth()/2);
        sprite.rotation._ = (lane % 2 == 0 ? 0 : 180);
        sprite.y._ = TILESIZE * 1.5 + TILESIZE * lane;
        
        car.lane = lane;
        car.gap = Math.floor(Math.random() * 200 + 100);
        car.direction = (lane % 2 == 0 ? 'RIGHT' : 'LEFT');
        
        cars.push(car);
        System.root.addChild(car.entity);
    }
}
