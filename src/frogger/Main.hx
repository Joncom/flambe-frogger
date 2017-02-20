package frogger;

import flambe.Entity;
import flambe.System;
import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.FillSprite;
import flambe.display.ImageSprite;
import flambe.script.Script;
import flambe.script.Sequence;
import flambe.script.MoveTo;
import flambe.script.CallFunction;

import flambe.swf.Library;
import flambe.swf.MovieSprite;
import flambe.input.KeyboardEvent;
import flambe.input.Key;

import haxe.Timer;

class Main
{
    // Constants
    private static inline var LANE_COUNT:Int = 5;
    private static inline var LANE_WIDTH:Int = 14;
    private static inline var TILESIZE:Int = 64;

    private static var frog:Entity;
    private static var frogSprite:MovieSprite;

    private static var road:Entity;
    private static var grass:Entity;

    private static var carTimer:Timer;

    private static var cars:Array<Car> = [];

    public static var pack:AssetPack;

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

        // Add one car to each lane
        for(lane in 0...LANE_COUNT) {
            addCar(lane);
        }

        // Create and start the game timer
        carTimer = new Timer(16);
        carTimer.run = function() {
            var y = TILESIZE;

            // Spawn new cars
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

            // Checker for collision against frog
            for(car in cars) {
                if(car.entity.get(ImageSprite).contains(frogSprite.x._, frogSprite.y._)) {
                    trace('hit');
                }
            }
        };

        frog = new Entity();
        var lib = new Library(pack, "frog");

        var frogIdle:MovieSprite = lib.createMovie("Frog.Idle", true);
        var frogHop:MovieSprite = lib.createMovie("Frog.Hop", true);
        for(sprite in [frogIdle, frogHop]) {
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
    }

    private static function addCar(lane) {
        var car = new Car();
        var sprite = car.entity.get(ImageSprite);

        sprite.x._ = (lane % 2 == 0 ? -sprite.getNaturalWidth()/2 : LANE_WIDTH * TILESIZE + sprite.getNaturalWidth()/2);
        sprite.x.animateTo((lane % 2 == 0 ? LANE_WIDTH * TILESIZE + sprite.getNaturalWidth()/2 : -sprite.getNaturalWidth()/2), 16);
        sprite.rotation._ = (lane % 2 == 0 ? 0 : 180);
        sprite.y._ = TILESIZE * 1.5 + TILESIZE * lane;
        
        car.lane = lane;
        car.gap = Math.floor(Math.random() * 200 + 100);
        car.direction = (lane % 2 == 0 ? 'RIGHT' : 'LEFT');
        
        cars.push(car);
        System.root.addChild(car.entity);
    }
}
