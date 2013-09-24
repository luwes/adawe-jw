package com.jeroenwijering.plugins {

	import flash.display.*;
	import flash.events.*;
	import flash.geom.ColorTransform;
	import flash.net.*;
	import flash.utils.*;
	import flash.media.Video;
	
	import com.jeroenwijering.events.*;
	import com.google.analytics.AnalyticsTracker; 
	import com.google.analytics.GATracker;
	import com.gskinner.motion.*;
	import com.gskinner.motion.easing.*;
	
	public class Adawe extends MovieClip implements PluginInterface {
	
	
		public var config:Object = {
		
			type:					"link",			// link | video
			delay:					1,				
			duration:				15,
			banner:					"ad.swf",
			bannerx:				0,
			bannery:				0,		
			banneranimation:		"slide",		// slide | fade | none
			bannerspeed:			0.7,
			link:					"",
			target:					"_blank",
			video:					"ad.flv",
			videoanimation:			"slide",		// slide | fade | none
			videospeed:				1,			
			analytics:				""				// UA-xxxxxxx-x
		}
		
		private var view:AbstractView;
	
		private var inited:Boolean = false;
		private var ldr:Loader;
		private var banner:MovieClip;
		private var adswf:Sprite;
		private var bannermask:Sprite;
		private var videomask:Sprite;
		private var closeban:CloseButton;
		private var closevid:CloseButton;
		private var adbut:AdButton;
		private var adtime:Number;
		
		private var initvi:Boolean = false;
		public var video:MovieClip;
		private var videocontent:Video;
		private var videocontainer:Sprite;
		private var videoback:Sprite;
		private var connection:NetConnection;
		private var stream:NetStream;
		private var vitime:Number;
		
		private var tracker:GATracker;
	
		
		public function Adawe() {
		
			closeban = new CloseButton();
			closeban.visible = false;
			addChild(closeban);
			
			closevid = new CloseButton();
			closevid.visible = false;
			addChild(closevid);
			
			adbut = new AdButton();
			adbut.visible = false;
			adbut.buttonMode = true;
			adbut.mouseChildren = false;
			adbut.addEventListener(MouseEvent.CLICK, showAd);
			addChild(adbut);
		}
		
		public function initializePlugin(vie:AbstractView):void {
			view = vie;
			
			if (config.analytics) tracker = new GATracker(this, config.analytics, "AS3", false);
			
			setColors();
	
			view.addControllerListener(ControllerEvent.RESIZE,resizeHandler);
			view.addModelListener(ModelEvent.STATE,stateHandler);
			view.addModelListener(ModelEvent.TIME,timeHandler);
			view.addViewListener(ViewEvent.STOP,stopHandler);
			view.addViewListener(ViewEvent.PLAY,playHandler);
		}
		
		private function setColors() {
			if(view.config.backcolor) {
				var back:ColorTransform = new ColorTransform();
				back.color = uint('0x'+view.config.backcolor.substr(-6));
				closeban.back.transform.colorTransform = back;
				closevid.back.transform.colorTransform = back;
				adbut.back.transform.colorTransform = back;
			}
			if(view.config.frontcolor) {
				var front:ColorTransform = new ColorTransform();
				front.color = uint('0x'+view.config.frontcolor.substr(-6));
				closeban.front.transform.colorTransform = front;
				closevid.front.transform.colorTransform = front;
				adbut.front.transform.colorTransform = front;
			}
		}
		
		private function timeHandler(e:ModelEvent) {
			var dur:Number = e.data.duration;
			var pos:Number = e.data.position;
			
			if(!inited && pos > config.delay && view.config.state == ModelStates.PLAYING) {
				inited = true;
				showAd();
			}		
		}
		
		private function showAd(e:MouseEvent=null):void {
			adbut.visible = false;
			
			ldr = new Loader();
			ldr.contentLoaderInfo.addEventListener(Event.INIT, adHandler);
			ldr.load(new URLRequest(getURL(config.banner)));
			if (tracker) tracker.trackEvent("Video Ads", "Viewed Banner Ad", config.banner);
		}
		
		private function adHandler(e:Event):void {
			banner = new MovieClip();
			banner.visible = false;
			addChild(banner);
			
			adswf = new Sprite();
			adswf.addChild(ldr);
			banner.addChild(adswf);
					
			bannermask = rect(this,'000000',config.width,config.height,config.x,config.y);
			banner.mask = bannermask;
			
			adswf.buttonMode = true;
			adswf.mouseChildren = false;
			
			closeban.visible = true;
			closeban.buttonMode = true;
			closeban.mouseChildren = false;
			closeban.addEventListener(MouseEvent.CLICK,showAdButton);
			closeban.x = adswf.width - closeban.width - 1;
			closeban.y = 6;
			banner.addChild(closeban);
			
			adtime = setTimeout(showAdButton, config.duration*1000);
			
			if(config.type == "link") {
				adswf.addEventListener(MouseEvent.CLICK,function(e:MouseEvent) {
					navigateToURL(new URLRequest(config.link),config.target);
					if (tracker) tracker.trackEvent("Video Ads", "Clicked Banner Ad", config.link);
				});
			} else if(config.type == "video") {
				adswf.addEventListener(MouseEvent.CLICK,showAdVideo);
			}
			
			resizeHandler();
			
			if (config.banneranimation == "slide") {
				
				banner.y = config.height;
				banner.visible = true;
				new GTween(banner, config.bannerspeed, {y:config.height-adswf.height-config.bannery}, {ease:Exponential.easeOut});
			}
			else if (config.banneranimation == "fade") {
				
				banner.alpha = 0;
				banner.visible = true;
				new GTween(banner, config.bannerspeed, {alpha:1});
			}
			else {
			
				banner.visible = true;
			}
		}
		
		private function showAdVideo(e:MouseEvent) {
			if(view.config.state == ModelStates.PLAYING) {
				view.sendEvent('PLAY');
			}
			stopBanner();
			
			video = new MovieClip();
			video.visible = false;
			video.x = config.x;
			video.y = config.y;
			videoback = rect(video,'000000',config.width,config.height,0,config.height,1);
			
			videomask = rect(this,'000000',config.width,config.height,config.x,config.y);
			video.mask = videomask;
			
			addChild(video);
			
			connection = new NetConnection();
			connection.connect(null);
			stream = new NetStream(connection);
			stream.addEventListener(AsyncErrorEvent.ASYNC_ERROR, asyncErrorHandler);
			stream.checkPolicyFile = true;
			stream.client = this;
			videocontent = new Video(320,240);
			videocontainer = new Sprite();
			videocontainer.addChild(videocontent);
			video.addChild(videocontainer);
			
			closevid.visible = true;
			closevid.buttonMode = true;
			closevid.mouseChildren = false;
			closevid.addEventListener(MouseEvent.CLICK, stopVideo);
			closevid.x = videoback.width - closevid.width - 10;
			closevid.y = config.height + 10;
			video.addChild(closevid);
			
			videocontent.attachNetStream(stream);
			stream.play(getURL(config.video));
		}
		
		private function asyncErrorHandler(event:AsyncErrorEvent):void {
    		trace(event.text);
		}
		
		public function onMetaData(obj:Object):void {
			initvi = true;
			if(obj.height != null && obj.width != null) {
	
		    	videocontent.width = obj.width;	 
		    	videocontent.height = obj.height;
		
				videocontent.x = (config.width - obj.width) / 2;
				videocontent.y = (config.height - obj.height) / 2 + config.height;
				
				video.visible = true;

				if (config.videoanimation == "slide") {
					
					new GTween(video, config.videospeed, {y:-config.height}, {ease:Exponential.easeOut});
				}
				else if (config.videoanimation == "fade") {
					
					video.alpha = videocontainer.alpha = 0;
					video.y = -config.height;
					
					var tween:GTween = new GTween(videocontainer, config.videospeed*0.5, {alpha:1}, {autoPlay:false});
					new GTween(video, config.videospeed*0.5, {alpha:1}, {nextTween:tween});
				}
				else {
					
					video.y = -config.height;
				}
				
				if (tracker) tracker.trackEvent("Video Ads", "Started Video Ad", config.video);
		 	}
		
			if(obj.duration != null) {
				vitime = setTimeout(completeVideo, (obj.duration-1)*1000)
			}
	
			videocontainer.buttonMode = true;
			videocontainer.mouseChildren = false;
			videocontainer.addEventListener(MouseEvent.CLICK,function(e:MouseEvent) {
				navigateToURL(new URLRequest(config.link),config.target);
				if (tracker) tracker.trackEvent("Video Ads", "Clicked Video Ad", config.link);
			});
		}
		
		private function stopVideo(e:MouseEvent=null) {
			inited = true;
			showAdButton();
			
			if (config.videoanimation == "slide") {
			
				new GTween(video, config.videospeed, {y:config.y}, {ease:Exponential.easeOut,onComplete:removeVideoPlay});
			}
			else if (config.videoanimation == "fade") {
				
				video.alpha = videocontainer.alpha = 1;
				
				var tween:GTween = new GTween(video, config.videospeed*0.5, {alpha:0}, {autoPlay:false,onComplete:removeVideoPlay});
				new GTween(videocontainer, config.videospeed*0.5, {alpha:0}, {nextTween:tween});
			}
			else {
			
				removeVideoPlay();
			}
		}
		
		private function completeVideo() {
			stopVideo();
			if (tracker) tracker.trackEvent("Video Ads", "Completed Video Ad", config.video);
		}
		
		private function removeVideoPlay(g:GTween=null) {
			removeVideo();

			if(view.config.state != ModelStates.PLAYING) {
				view.sendEvent('PLAY');
			}
		}
		
		private function removeVideo() {
			if(video && contains(video)) {
				removeChild(video);
			}
			clearTimeout(vitime);
			stream.close();
			initvi = false;
		}
		
		private function resizeHandler(e:ControllerEvent=null) {
			if(!adswf) return;
			
			trace(view.config.fullscreen);
	
			var wid:Number = config.width;
			var hei:Number = config.height;
			
			bannermask.width = wid;
			bannermask.height = hei;
			
			banner.x = (wid - adswf.width + config.bannerx) * 0.5;
			banner.y = hei - adswf.height - config.bannery;
			
			adbut.x = wid - adbut.width - 5;
			adbut.y = hei - adbut.height - 5;
			
			if(videocontent) {
			
				video.y = -hei;
				videomask.width = wid;
				videomask.height = hei;
				videoback.y = hei;
				videoback.width = wid;
				videoback.height = hei;
				videocontent.x = (wid - videocontent.width) / 2;
				videocontent.y = (hei - videocontent.height) / 2 + hei;
				closevid.x = videoback.width - closevid.width - 10;
				closevid.y = hei + 10;
			}
		}
		
		private function showAdButton(e:MouseEvent=null) {
			removeBanner();
			closeban.visible = false;
			
			adbut.visible = true;
			adbut.x = config.width - adbut.width - 5;
			adbut.y = config.height - adbut.height - 5;
		}
		
		private function getURL(file:String):String {
			var swf:String = this.loaderInfo.url;
			return (file.indexOf('http://') != -1 || file.substr(0, 1) == "/") ? file : swf.substr(0, swf.lastIndexOf("/") + 1) + file;
		}
		
		private function removeBanner():void {
			if(banner && contains(banner)) {

				if (config.banneranimation == "slide") {
				
					new GTween(banner, config.bannerspeed, {y:config.height}, {ease:Exponential.easeOut, onComplete:removeChildBanner});
				}
				else if (config.banneranimation == "fade") {
					
					new GTween(banner, config.bannerspeed, {alpha:0}, {onComplete:removeChildBanner});
				}
				else {
					
					removeChildBanner()
				}
			}
			clearTimeout(adtime);
		}
		
		private function removeChildBanner(g:GTween=null):void {
		
			removeChild(banner);
		}
		
		private function stopBanner():void {
			removeBanner();
			adbut.visible = false;
			inited = false;
		}
		
		private function playHandler(e:ViewEvent=null) {
			if (initvi) stopVideo();
		}
		
		private function stopHandler(e:ViewEvent=null) {
			if (banner) stopBanner();
			if (video) removeVideo();
		}
		
		private function stateHandler(e:ModelEvent) {
			if (e.data.newstate == ModelStates.COMPLETED) {
				stopBanner();
			}
		}
		
		public static function rect(tgt:Sprite,col:String,wid:Number,hei:Number,xps:Number=0,yps:Number=0,alp:Number=1):Sprite {
			var rct:Sprite = new Sprite();
			rct.x = xps;
			rct.y = yps;
			rct.graphics.beginFill(uint('0x'+col),alp);
			rct.graphics.drawRect(0,0,wid,hei);
			tgt.addChild(rct);
			return rct;
		}
	}
}