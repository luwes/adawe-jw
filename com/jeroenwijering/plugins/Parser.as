package com.jeroenwijering.plugins {

    public class Parser extends Object
    {
        public static var CONFIG:Object = {publisher:0, initial_delay:4, display_duration:20, textcolor_title:"0xffffff", textcolor_description:"0xcccccc", textcolor_link:"0xaad03e", mouseover_color:"0xcdcdcd", background_color:"0x000000", opacity:80, about_txt:"Ads by LongTail", about_url:"http://www.longtailvideo.com", Site:-1, TagID:-1, Channel:-1};
        private static var ELEMENTS:Object = {title:undefined, description:undefined, display_url:undefined, click_url:undefined, image:undefined};

        public function Parser()
        {
            return;
        }// end function

        public static function parseConfig(param1:XML) : Object
        {
            var _loc_2:*;
            var _loc_3:*;
            var _loc_4:*;
            var _loc_5:*;
            _loc_2 = new Object();
            _loc_3 = param1.children()[0];
            for (_loc_4 in Parser.CONFIG)
            {
                // label
                _loc_2[_loc_4] = Parser.CONFIG[_loc_4];
            }// end of for ... in
            for each (_loc_5 in _loc_3.children())
            {
                // label
                if (_loc_2.hasOwnProperty(_loc_5.localName()))
                {
                    _loc_2[_loc_5.localName()] = _loc_5.text().toString();
                }// end if
            }// end of for each ... in
            return _loc_2;
        }// end function

        private static function parseAd(param1:XML) : Object
        {
            var _loc_2:*;
            var _loc_3:*;
            _loc_2 = new Object();
            for each (_loc_3 in param1.children())
            {
                // label
                _loc_2[_loc_3.localName()] = _loc_3.text().toString();
            }// end of for each ... in
            return _loc_2;
        }// end function

        public static function parseAds(param1:XML) : Array
        {
            var _loc_2:*;
            var _loc_3:*;
            var _loc_4:*;
            _loc_2 = new Array();
            _loc_3 = param1.children()[1];
            for each (_loc_4 in _loc_3.children())
            {
                // label
                if (_loc_4.localName() == "item")
                {
                    _loc_2.push(Parser.parseAd(_loc_4));
                }// end if
            }// end of for each ... in
            return _loc_2;
        }// end function

    }
}