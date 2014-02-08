package
{
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.NetStatusEvent;
	import flash.events.ProgressEvent;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLStream;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.ui.Keyboard;
	import flash.ui.KeyboardType;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	import org.osmf.events.TimeEvent;

	
	[SWF(width="800",height="450")]
	public class ChangeSpeed extends Sprite
	{
		private var _video:Video;
		private var _nc:NetConnection;
		private var _ns:NetStream;
		private var _clipLoader:URLStream;
		
		private var _result:ByteArray = new ByteArray();
		
		
		private var _url:String = "http://cdn-cc-dev-110.video-tx.com/rendition/201401/96992142907408384/96992144786456576/0d/134784336728686592/134784394710745600/r134784394710745600-500k-672x378.flv";
//		private var _url:String = "BeautifulOnes_sample.flv";
		
		
		public function ChangeSpeed()
		{
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		
		private function onAddedToStage(event:Event):void
		{
			init();
		}
		
		
		private var _urlInput:TextField = new TextField();
		private function init():void
		{
			_urlInput.width = 500;
			_urlInput.height = 30;
			_urlInput.type = TextFieldType.INPUT;
			_urlInput.text = _url;
			_urlInput.addEventListener(KeyboardEvent.KEY_DOWN, onUrlInputKeyDown);
			this.addChild(_urlInput);
			
			_nc = new NetConnection();
			_nc.addEventListener(NetStatusEvent.NET_STATUS, onNCNetStatus);
			_nc.connect(null);
			
			_clipLoader = new URLStream();
			_clipLoader.addEventListener(ProgressEvent.PROGRESS, onClipLoaderProgress);
			_clipLoader.addEventListener(Event.COMPLETE, onClipLoaderComplete);
			
//			getClip(_urlInput.text);
		}
		
		
		private function onUrlInputKeyDown(e:KeyboardEvent):void
		{
			if(e.keyCode == Keyboard.ENTER)
			{
				_ns.seek(0);
				_ns.appendBytesAction(NetStreamAppendBytesAction.RESET_BEGIN);
				streamBytes.clear();
				getClip(_urlInput.text);
			}
		}
		
		
		private function getClip(url:String):void
		{
//			trace("getClip: ", url);
			_clipLoader.load(new URLRequest(url));
		}
		
		private function onNCNetStatus(event:NetStatusEvent):void
		{
			switch(event.info.code)
			{
				case "NetConnection.Connect.Success": //NetConnectionCode.CONNECT_SUCCESS :
					connectStream();
					break ;
				case "NetStream.Play.StreamNotFound": //NetStreamCodes.NETSTREAM_PLAY_STREAMNOTFOUND :
					throw new Error("StreamNotFound");
					break ;
			}
		}
		
		private function connectStream():void
		{
			_ns = new NetStream(_nc);
			_ns.client = {onMetaData:onMetaData};
			_ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
			_ns.play(null);
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
			
			_video = new Video(672, 378);
			_video.y = 40;
			_video.attachNetStream(_ns);
			this.addChild(_video);
		}
		
		private function onEnterFrame(event:Event):void
		{
//			if(_ns)
//				trace(_ns.time, _ns.bufferLength);
		}
		
		private function onMetaData(obj:Object):void
		{
			trace(obj);
		}
		
		private function onNetStatus(e:NetStatusEvent):void
		{
//			trace('[AdaptiveStreamLoadTrait] netStatus: ' + e.info.code);
			switch(e.info.code)
			{
				case 'NetStream.SeekStart.Notify':
				case 'NetStream.Seek.Notify':
//					trace("seek notify");
					break;
				case 'NetStream.Buffer.Flush':
					break;
				case 'NetStream.Buffer.Empty':
//					checkStreamComplete();
					break;
				case 'NetStream.Buffer.Full':
//					completeSeeking();
					break;
			}
		}
		
		private var streamBytes:ByteArray = new ByteArray();
		private var flvHeader:ByteArray = null;
		private var tags:Vector.<FLVTag> = new Vector.<FLVTag>();
		private var tagIndex:uint = 0;
		
		private function onClipLoaderProgress(event:Event):void
		{
			if(_clipLoader.bytesAvailable < 1000)
				return ;
			
//			trace("progress: ", _clipLoader.bytesAvailable);
			_clipLoader.readBytes(streamBytes, streamBytes.length);
			
			if(!flvHeader)
				parseFLVHeader(streamBytes);
			
			parseFLV(streamBytes);
		}
		
		private function onClipLoaderComplete(event:Event):void
		{
//			trace("complete: ", _clipLoader.bytesAvailable);
		}
		
		
		private function parseFLVHeader(bytes:ByteArray):void
		{
			var fileSignature:String = bytes.readUTFBytes(3); // 3B
			var version:uint = bytes.readUnsignedByte(); // 1B
			
			var typeFlag:uint = bytes.readUnsignedByte(); // 1B
			var TypeFlagsReserved1:uint = typeFlag >> 3;
			var TypeFlagsAudio:uint = typeFlag & 0x3;
			var TypeFlagsReserved2:uint = typeFlag & 0x2;
			var TypeFlagsVideo:uint = typeFlag & 0x1;
			
			var dataOffset:uint = bytes.readUnsignedInt(); // 4B
			/////// 
			var headerTagSize:uint = bytes.readUnsignedInt(); // 4B
			
			flvHeader = new ByteArray();
			bytes.position = 0;
			bytes.readBytes(flvHeader, 0, 13);
			
			_ns.appendBytes(flvHeader);
		}
		
		private function parseFLV(bytes:ByteArray):void
		{
			// TODO: add timeout check.
			while(bytes.bytesAvailable > 0)
			{
				var tag:FLVTag = FLVTagFactory.getTag(bytes);
				if(tag)
				{
					tags.push(tag);
//					bytes.position += FLVTag.PREV_TAG_BYTE_COUNT;
				}
				else
					break;
			}
			parseTag();
		}
		
		private function parseTag():void
		{
			while(tagIndex < tags.length)
			{
				var tag:FLVTag = tags[tagIndex] ;
				
				if(tag.type == FLVTag.TAG_TYPE_VIDEO)
				{
//					tag.timestamp = tag.timestamp >> 1 ;
				}
				
				var tagType:String = "";
				switch(tag.type)
				{
					case 8:
						tagType = "audio ";
						break;
					case 9:
						tagType = "video ";
						break;
					case 18:
						tagType = "script";
						break;
				}

				trace(tagType, tag.bytes.length, tagIndex, tags.length, _ns.bufferLength);
				_ns.appendBytes(tag.bytes);
				tagIndex ++;
			}
			
		}
		
	}
}

