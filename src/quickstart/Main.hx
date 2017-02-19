package quickstart;

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

class Main
{
    // Constants
    private static inline var TILE_WIDTH:Int = 14;
    private static inline var TILE_HEIGHT:Int = 7;
    private static inline var TILESIZE:Int = 64;

    private static var frog:Entity;
    private static var frogSprite:MovieSprite;

    private static var road:Entity;
    private static var grass:Entity;

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
        road = new Entity();
        for(y in 1...(TILE_HEIGHT - 1)) {
            for(x in 0...TILE_WIDTH) {
                var tile = new ImageSprite(pack.getTexture("road-tile"));
                tile.x._ = x * TILESIZE;
                tile.y._ = y * TILESIZE;
                road.addChild(new Entity().add(tile));
            }
        }
        System.root.addChild(road);

        grass = new Entity();
        for(y in [0,TILE_HEIGHT-1]) {
            for(x in 0...TILE_WIDTH) {
                var tile = new ImageSprite(pack.getTexture("grass-tile"));
                tile.x._ = x * TILESIZE;
                tile.y._ = y * TILESIZE;
                tile.scaleX._ = 2;
                tile.scaleY._ = 2;
                grass.addChild(new Entity().add(tile));
            }
        }
        System.root.addChild(grass);

        frog = new Entity();
        var lib = new Library(pack, "frog");

        var frogIdle:MovieSprite = lib.createMovie("Frog.Idle", true);
        var frogHop:MovieSprite = lib.createMovie("Frog.Hop", true);

        frogSprite = frogIdle;
        frogSprite.x._ = 256;
        frogSprite.y._ = 256;

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
}
