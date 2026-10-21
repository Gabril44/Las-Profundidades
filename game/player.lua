local Player = {}

function Player.create(x,y,tile)
    return {
        x=x or 3*tile,y=y or 2*tile,w=27,h=42,vx=0,vy=0,grounded=false,facing=1,coyote=0,
        jumpBuffer=0,hp=4,maxHp=4,light=100,lanternOn=true,invuln=0,swing=0,hook=nil,hookCooldown=0,
        lastHookX=nil,lastHookY=nil,chainTarget=nil,chainAssistTimer=0,hookBuffer=0,pickTimer=0,
        flashTimer=0,mantle=nil,mantlePose=0,stepTimer=0,walkCycle=0,walkBlend=0,
        hookKick=0,hookAimX=0,hookAimY=-1,squash=0,turnTimer=0,idleTime=0,ropeSoundTimer=0,
        lowLightTimer=0,action=nil,actionTime=0,actionDuration=0,actionStrength=1,
        landTimer=0,releaseTimer=0,airTime=0,pickAimX=1,pickAimY=0,
        bellyX=0,bellyY=0,bellyVX=0,bellyVY=0,
        gearX=0,gearY=0,gearVX=0,gearVY=0,
        beardX=0,beardY=0,beardVX=0,beardVY=0,
        helmetAngle=0,helmetVelocity=0,
        edgeFactor=0,exertion=0,danger=0,hurtTimer=0,breathTimer=0,depth=1,
        packAngle=0,packVelocity=0,lampAngle=0,lampVelocity=0,beltAngle=0,beltVelocity=0,
        hookFailTimer=0,pickFailTimer=0,refugeFactor=0,zoneGestureTimer=0,astralEcho=0,
        blinkClock=1.2,blinkAmount=0,lookX=0,lookY=0,exhausted=0,
    }
end

return Player
