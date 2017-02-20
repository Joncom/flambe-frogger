package frogger;

import flambe.Entity;
import flambe.System;
import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.FillSprite;
import flambe.display.ImageSprite;
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
    private static inline var LANE_COUNT:Int = 5;
    private static inline var LANE_WIDTH:Int = 14;
    private static inline var TILESIZE:Int = 64;

    private static var frog:Entity;
    private static var frogSprite:MovieSprite;
    private static var frogLastCarTouched:Int;

    private static var frogIdle:MovieSprite;
    private static var frogHop:MovieSprite;
    private static var frogKilled:MovieSprite;

    private static var road:Entity;
    private static var grass:Entity;

    private static var baseCarSpeed:Int = 25;
    private static var laneSpeedFactor:Array<Int> = [4, 3, 6, 2, 5];

    private static var cars:Array<Car> = [];

    public static var pack:AssetPack;

    private static var lastFrame:Float = 0;

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

        frog = new Entity();

        var lib = new Library(pack, "frog");
        frogIdle = lib.createMovie("Frog.Idle", true);
        frogHop = lib.createMovie("Frog.Hop", true);
        frogKilled = lib.createMovie("Frog.Killed", true);
        
        for(sprite in [frogIdle, frogHop, frogKilled]) {
            sprite.scaleX._ = 0.5;
            sprite.scaleY._ = 0.5;
        }

        frogSprite = frogIdle;
        frogSprite.x._ = 32;
        frogSprite.y._ = 32;

        frog.add(frogSprite);
        System.root.addChild(frog);

        System.keyboard.down.connect(function(event:KeyboardEvent) {
            var moveX = 0;
            var moveY = 0;
            if(event.key == Key.Down) {
                moveY = TILESIZE;
            } else if(event.key == Key.Up) {
                moveY = -TILESIZE;
            } else if(event.key == Key.Left) {
                moveX = -TILESIZE;
            } else if(event.key == Key.Right) {
                moveX = TILESIZE;
            }
            // Can move?
            if(frogSprite == frogIdle) {
                // Trying to move?
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
        });

        // Add one car to each lane
        for(lane in 0...LANE_COUNT) {
            addCar(lane);
        }
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
            var speed = baseCarSpeed * laneSpeedFactor[car.lane];
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
