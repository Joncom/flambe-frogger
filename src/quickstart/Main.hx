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

import flambe.display.Font;
import flambe.display.TextSprite;
import flambe.input.PointerEvent;
import flambe.util.SignalConnection;
import haxe.Timer;

class Main
{
    private static var frog:Entity;

    // Constants
    private static inline var GAME_TIME:Int = 10;

    // Assets
    private static var assetPack:AssetPack;
    private static var gameFont:Font;

    // Screens
    private static var gameScreen:Entity;
    private static var gameOverScreen:Entity;

    // Game data
    private static var time:Int;
    private static var score:Int;
    private static var planeSignalConnection:SignalConnection;

    // Game screen content
    private static var levelTimer:Timer;
    private static var planeSprite:ImageSprite;
    private static var scoreText:TextSprite;
    private static var timeText:TextSprite;

    // Game over screen content
    private static var gameOverScoreText:TextSprite;
    private static var playAgainButtonText:TextSprite;

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
        frog = new Entity();
        var lib = new Library(pack, "frog");

        var frogIdle:MovieSprite = lib.createMovie("Frog.Idle", true);
        frogIdle.x._ = 256;
        frogIdle.y._ = 256;
        frog.add(frogIdle);
        System.root.addChild(frog);

        var frogHop:MovieSprite = lib.createMovie("Frog.Hop", true);

        System.keyboard.down.connect(function(event:KeyboardEvent) {
            if(event.key == Key.Down) {
                frogIdle.y._ += 10;
            } else if(event.key == Key.Up) {
                frogIdle.y._ -= 10;
            } else if(event.key == Key.Left) {
                frogIdle.x._ -= 10;
            } else if(event.key == Key.Right) {
                frogIdle.x._ += 10;
            }
            frog.remove(frogIdle);
            frog.add(frogHop);
            frogHop.x._ = frogIdle.x._;
            frogHop.y._ = frogIdle.y._;
            frogHop.looped.connect(function() {
                trace("Done hop");
                frog.remove(frogHop);
                frog.add(frogIdle);
            }).once();
        });

        return;

        // Store the asset pack for use later on
        assetPack = pack;
        // Grab the font from the asset pack for use later on
        gameFont = new Font(assetPack, "font");

        // Add a basic background that will be present on all screens
        var gameBG = new FillSprite(0x033E6B, System.stage.width, System.stage.height);
        System.root.addChild(new Entity().add(gameBG));

        // Create the two game screens
        CreateGameScreen();
        CreateGameOverScreen();

        // Show the game screen
        ShowGameScreen();
    }

    private static function CreateGameScreen():Void {

        // Create the basic entity that will contain our game elements
        gameScreen = new Entity();

        // Create the plane and add it to the middle of the screen
        var plane:Entity = new Entity();
        planeSprite = new ImageSprite(assetPack.getTexture("plane"));
        planeSprite.centerAnchor();
        planeSprite.x._ = System.stage.width / 2;
        planeSprite.y._ = System.stage.height / 2;
        plane.add(planeSprite);
        gameScreen.addChild(plane);

        // Create a UI section for displaying the game score
        var scoreSection:Entity = new Entity();
        var scoreBG:FillSprite = new FillSprite(0xFF9200, System.stage.width, 50);
        scoreSection.add(scoreBG);

        scoreText = new TextSprite(gameFont, "Score: 0000");
        scoreSection.addChild(new Entity().add(scoreText));

        gameScreen.addChild(scoreSection);

        // Create a UI section for displaying the game timer
        var timeSection:Entity = new Entity();
        var timeBG = new FillSprite(0x0B61A4, System.stage.width, 50);
        timeBG.y._ = System.stage.height - timeBG.height._;
        timeSection.add(timeBG);

        timeText = new TextSprite(gameFont, "Time:");
        timeSection.addChild(new Entity().add(timeText));

        gameScreen.addChild(timeSection);
    }

    private static function CreateGameOverScreen():Void {

        // Create the basic entity that will contain our game over elements
        gameOverScreen = new Entity();

        // Create a UI section for displaying the "Game Over" header
        var headerSection = new Entity();
        var headerBG = new FillSprite(0xFF9200, System.stage.width, 50);
        headerBG.y._ = System.stage.height / 2 - (headerBG.height._ / 2);
        headerSection.add(headerBG);

        var gameOverText = new TextSprite(gameFont, "GAME OVER");
        gameOverText.centerAnchor();
        gameOverText.x._ = System.stage.width / 2;
        gameOverText.y._ += gameOverText.getNaturalHeight() / 2;
        headerSection.addChild(new Entity().add(gameOverText));

        gameOverScreen.addChild(headerSection);

        // Create a UI section for displaying the game score
        var scoreSection:Entity = new Entity();
        var scoreBG = new FillSprite(0x0B61A4, System.stage.width, 50);
        scoreBG.y._ = System.stage.height / 2 + (scoreBG.height._ / 2);
        scoreSection.add(scoreBG);

        gameOverScoreText = new TextSprite(gameFont, "SCORE: 000000");
        gameOverScoreText.align = TextAlign.Center;
        gameOverScoreText.centerAnchor();
        gameOverScoreText.x._ = (System.stage.width / 2) + (gameOverScoreText.getNaturalWidth() / 2);
        gameOverScoreText.y._ += gameOverScoreText.getNaturalHeight() / 2;
        scoreSection.addChild(new Entity().add(gameOverScoreText));

        gameOverScreen.addChild(scoreSection);

        // Create a text sprite that will be our "Play again" button
        playAgainButtonText = new TextSprite(gameFont, "PLAY AGAIN");
        playAgainButtonText.centerAnchor();
        playAgainButtonText.x._ = System.stage.width / 2;
        playAgainButtonText.y._ = scoreBG.y._ + (playAgainButtonText.getNaturalHeight() * 2);
        gameOverScreen.addChild(new Entity().add(playAgainButtonText));
    }

    private static function ShowGameScreen():Void {

        // Reset game before showing it
        time = GAME_TIME;
        score = 0;

        timeText.text = "Time: " + time;
        scoreText.text = "Score: " + score;

        planeSprite.scaleX._ = 1;
        planeSprite.scaleY._ = 1;

        // Remove the game over screen and add the game screen
        System.root.removeChild(gameOverScreen);
        System.root.addChild(gameScreen);

        // Create and start the game timer
        levelTimer = new Timer(1000);
        levelTimer.run = OnTimer;

        // Listen for the pointerUp signal on the plane sprite, store a reference to its signal connection so that it can be cleaned up
        planeSignalConnection = planeSprite.pointerUp.connect(OnClickPlane);
    }

    private static function OnTimer():Void {

        // Decrease the time remaining
        time--;
        // If we have less than 0 seconds remaining
        if (time < 0) {
            // Stop the level timer, and null it out
            levelTimer.stop();
            levelTimer = null;

            // Dispose of the listener attached to the plane sprite
            planeSignalConnection.dispose();

            // Show the game over screen
            ShowGameOverScreen();

        // If we still have time remaining
        } else {
            // Set the timer text
            timeText.text = "Time: " + time;

        }
    }

    private static function OnClickPlane(event:PointerEvent):Void {

        // Increment the score, set the score text
        score++;
        scoreText.text = "Score: " + score;

        // Slowly scale up the plane sprite by a 100th of the score
        planeSprite.scaleX.animateBy(score/100, 0.25);
        planeSprite.scaleY.animateBy(score/100, 0.25);

        // Play the sound effect
        assetPack.getSound("hit").play();
    }

    private static function ShowGameOverScreen():Void {

        // Remove the game screen and add the game over screen
        System.root.removeChild(gameScreen);
        System.root.addChild(gameOverScreen);

        // Set the score text
        gameOverScoreText.text = "Score: " + score;

        // Listen for the pointerUp signal on the play again button using the once function, this way it will clean up after itself
        playAgainButtonText.pointerUp.connect(OnPlayAgain).once();
    }

    private static function OnPlayAgain(event:PointerEvent):Void {

        // Change back to the game screen
        ShowGameScreen();
    }
}
