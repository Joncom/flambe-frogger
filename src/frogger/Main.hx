package frogger;

import flambe.Entity;
import flambe.System;
import flambe.asset.AssetPack;
import flambe.asset.Manifest;
import flambe.display.FillSprite;
import flambe.display.ImageSprite;

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
                if(!car.nextCarSpawned && car.entity.get(ImageSprite).x._ >= car.gap) {
                    addCar(car.lane);
                    car.nextCarSpawned = true;
                }
            }

            // Remove old cars
            if(cars.length > 0) {
                var i = cars.length - 1;
                while(i >= 0) {
                    if(cars[i].entity.get(ImageSprite).x._ >= LANE_WIDTH * TILESIZE) {
                        System.root.removeChild(cars[i].entity);
                        cars.splice(i, 1);
                    }
                    i--;
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
                    if(moveX != 0) {
                        frogHop.x.animateTo(frogHop.x._ + moveX, frogHop.symbol.duration);    
                    }
                    if(moveY != 0) {
                        frogHop.y.animateTo(frogHop.y._ + moveY, frogHop.symbol.duration);
                    }

                    frogHop.looped.connect(function() {
                        // Restore idle animation
                        frogIdle.x._ = frogHop.x._;
                        frogIdle.y._ = frogHop.y._;
                        frogIdle.rotation._ = frogHop.rotation._;
                        frog.remove(frogHop);
                        frog.add(frogIdle);
                        frogSprite = frogIdle;
                    }).once();
                }
            }
        });
    }

    private static function addCar(lane) {
        var car = new Car();
        var sprite = car.entity.get(ImageSprite);

        sprite.x._ = -sprite.getNaturalWidth();
        sprite.y._ = TILESIZE + TILESIZE * lane;
        sprite.x.animateTo(LANE_WIDTH * TILESIZE, 2);
        
        car.lane = lane;
        car.gap = 100;
        car.nextCarSpawned = false;
        
        cars.push(car);
        System.root.addChild(car.entity);
    }
}
