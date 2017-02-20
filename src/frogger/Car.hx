package frogger;

import flambe.Entity;
import flambe.display.ImageSprite;

class Car
{
    private static var carNames = ["celica", "civic", "semi", "taxi", "viper"];
    private static var idCounter:Int = 0;

    public var entity:Entity;

    public var id:Int;
    public var gap:Int;
    public var lane:Int;
    public var nextCarSpawned:Bool;
    public var direction:String;

    public function new()
    {
        this.id = idCounter++;

        var name = carNames[Math.floor(Math.random() * carNames.length)];
        var sprite = new ImageSprite(Main.pack.getTexture("car-" + name));
        sprite.centerAnchor();
        
        this.entity = new Entity();
        this.entity.add(sprite);

        this.lane = 0;
        this.gap = 100;
        this.nextCarSpawned = false;
    }
}
