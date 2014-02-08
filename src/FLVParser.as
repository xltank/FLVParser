package
{
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.NetStatusEvent;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.NetStreamAppendBytesAction;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.ui.Keyboard;
	import flash.ui.KeyboardType;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	
	public class FLVParser extends Sprite
	{
		private var _video:Video;
		private var _nc:NetConnection;
		private var _ns:NetStream;
		private var _clipLoader:URLLoader;
		
		private var _result:ByteArray = new ByteArray();
		
		
//		private var _url:String = "http://localhost/Beautiful Ones.flv";
		private var _url:String = "BeautifulOnes_sample.flv";
		
		
		public function FLVParser()
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
//			_urlInput.addEventListener(KeyboardEvent.KEY_DOWN, onUrlInputKeyDown);
			this.addChild(_urlInput);
			
			_nc = new NetConnection();
			_nc.addEventListener(NetStatusEvent.NET_STATUS, onNCNetStatus);
			_nc.connect(null);
			
			_clipLoader = new URLLoader();
			_clipLoader.dataFormat = URLLoaderDataFormat.BINARY;
			_clipLoader.addEventListener(Event.COMPLETE, onClipLoadedComplete);
			
			getClip(_urlInput.text);
		}
		
		
		/*
		private function onUrlInputKeyDown(e:KeyboardEvent):void
		{
			getClip(_urlInput.text);
		}*/
		
		
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
			
			_video = new Video(672, 378);
			_video.y = 40;
			_video.attachNetStream(_ns);
			this.addChild(_video);
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
		
		
		private var _tsIndex:int = 0;
		private function onClipLoadedComplete(event:Event):void
		{
			var bytes:ByteArray = _clipLoader.data as ByteArray;
			trace("Clip bytes: ", bytes.length);
			stream.clear();
			parseFLV(bytes);
		}
		
		
		private var stream:ByteArray = new ByteArray();
		private function parseFLV(bytes:ByteArray):void
		{
			/*
			Signature  UI8  Signature byte always 'F' (0x46) 
			Signature  UI8  Signature byte always 'L' (0x4C) 
			Signature  UI8  Signature byte always 'V' (0x56) 
			*/
			var fileSignature:String = bytes.readUTFBytes(3);
			trace("fileSignature", fileSignature);
			/*Version  UI8  File version (for example, 0x01 for FLV version 1) */
			var version:uint = bytes.readUnsignedByte();
			trace("version", version);
			/*
			TypeFlagsReserved  UB [5]  Shall be 0 
			TypeFlagsAudio     UB [1]  1 = Audio tags are present 
			TypeFlagsReserved  UB [1]  Shall be 0 
			TypeFlagsVideo     UB [1]  1 = Video tags are present 
			*/
			var typeFlag:uint = bytes.readUnsignedByte();
			var TypeFlagsReserved1:uint = typeFlag >> 3;
			var TypeFlagsAudio:uint = typeFlag & 0x3;
			var TypeFlagsReserved2:uint = typeFlag & 0x2;
			var TypeFlagsVideo:uint = typeFlag & 0x1;
//			trace("typeFlag", typeFlag, TypeFlagsReserved1, TypeFlagsAudio, TypeFlagsReserved2, TypeFlagsVideo);
			/*DataOffset  UI32  The length of this header in bytes */
			var dataOffset:uint = bytes.readUnsignedInt();
//			trace("dataOffset", dataOffset);
			/*PreviousTagSize0  UI32  Always 0 */
			var headerTagSize:uint = bytes.readUnsignedInt();
			trace("headerTagSize", headerTagSize);
			
			while(bytes.bytesAvailable > 0)
			{
				/* 
				Reserved  UB [2]  Reserved for FMS, should be 0 
				Filter    UB [1]  Indicates if packets are filtered. 
									0 = No pre-processing required. 
									1 = Pre-processing (such as decryption) of the packet is 
									required before it can be rendered. 
									Shall be 0 in unencrypted files, and 1 for encrypted tags. 
				TagType   UB [5]  Type of contents in this tag. The following types are 
									defined:  
									8 = audio  
									9 = video  
									18 = script data  
				*/
				var tagHeader:uint = bytes.readUnsignedByte();
				var tagReserved:uint = tagHeader >> 6;
				var tagFilter:uint = tagHeader & 0x20;
				var tagType:uint = tagHeader & 0x1F;
				
				/*
				DataSize  UI24  Length of the message. Number of bytes after StreamID to 
				end of tag (Equal to length of the tag – 11) 
				*/
				var tagDataSize:uint = (bytes.readUnsignedShort() << 8) + bytes.readUnsignedByte();
				var tagSize:uint = tagDataSize + 11;
//				trace("tag DataSize", tagDataSize);
//				trace("tag size", tagSize);
				
				/*
				Timestamp  UI24  Time in milliseconds at which the data in this tag applies. 
				This value is relative to the first tag in the FLV file, which always has a timestamp of 0.
				*/
				/*
				TimestampExtended  UI8  Extension of the Timestamp field to form a SI32 value. This 
				field represents the upper 8 bits, while the previous 
				Timestamp field represents the lower 24 bits of the time in 
				milliseconds.   
				*/
				var time:uint = bytes.readUnsignedInt();
				var timestamp:uint = time & 0xFF + time >> 8;
				trace("timestamp", timestamp);
				
				/*StreamID  UI24  Always 0.  */
				var streamID:uint = bytes.readUnsignedShort() << 8 + bytes.readUnsignedByte();
				
				var tagData:ByteArray = new ByteArray();
				bytes.readBytes(tagData, 0, tagDataSize);
				trace("tagData size: ", tagData.length);
				switch(tagType)
				{
					case 8:
						trace("audio tag")
						parseAudioTagData(tagData);
						break;
					case 9:
						trace("video tag")
						parseVideoTagData(tagData);
						break;
					case 18:
						trace("script tag -------------------")
//						parseScriptTagData(tagData);
						parseMetaData(tagData);
						break;
				}
				
				/*
				PreviousTagSize1  UI32  Size of previous tag, including its header, in bytes. 
				For FLV version 1, this value is 11 plus the DataSize of the previous tag. 
				*/
				bytes.position += 4;
			}
		}
		
		
		private function parseAudioTagData(data:ByteArray):void
		{
			/*
			(See notes following table, for special encodings) 
			SoundFormat UB [4]  Format of SoundData. The following values are defined: 
			Formats 7, 8, 14, and 15 are reserved. 
			AAC is supported in Flash Player 9,0,115,0 and higher. 
			Speex is supported in Flash Player 10 and higher.  
			*/
			var firstByte:uint = data.readUnsignedByte();
			var soundFormat:uint = firstByte >> 4;
			var soundRate:uint = firstByte & 0xC;
			var soundSize:uint = firstByte & 0x2;
			var soundType:uint = firstByte & 0x1;
			switch(soundFormat)
			{
				case 0: // 
					trace("soundFormat", "Linear PCM, platform endian ");
					break;
				case 1: // 
					trace("soundFormat", "ADPCM");
					break;
				case 2: // 
					trace("soundFormat", "MP3");
					break;
				case 3: // 
					trace("soundFormat", "Linear PCM, little endian ");
					break;
				case 4: // 
					trace("soundFormat", "Nellymoser 16 kHz mono ");
					break;
				case 5: // 
					trace("soundFormat", "Nellymoser 8 kHz mono ");
					break;
				case 6: // 
					trace("soundFormat", "Nellymoser ");
					break;
				case 7: // 
					trace("soundFormat", "G.711 A-law logarithmic PCM ");
					break;
				case 8: // 
					trace("soundFormat", "G.711 mu-law logarithmic PCM ");
					break;
				case 9: // 
					trace("soundFormat", "reserved");
					break;
				case 10: // 
					trace("soundFormat", "AAC");
					/*
					AACPacketType UI8 (IF SoundFormat == 10) 
					The following values are defined: 
					0 = AAC sequence header 
					1 = AAC raw  
					*/
					var aacPacketType:uint = data.readUnsignedByte();
					if(aacPacketType == 0)
						trace("AACPacketType", "AAC sequence header");
					else if(aacPacketType == 0)
						trace("AACPacketType", "AAC raw");
					/*
					If the SoundFormat indicates AAC, the SoundType should be 1 (stereo) 
					and the SoundRate should be 3 (44 kHz). 
					However, this does not mean that AAC audio in FLV is always stereo, 44 kHz data. 
					Instead, the Flash Player ignores these values 
					and extracts the channel and sample rate data is encoded in the AAC bit stream.  
					*/
					break;
				case 11: // 
					trace("soundFormat", "Speex");
					/*
					If the SoundFormat indicates Speex, the audio is compressed mono sampled at 16 kHz, 
					the SoundRate shall be 0, the SoundSize shall be 1, and the SoundType shall be 0.  
					*/
					break;
				case 14: // 
					trace("soundFormat", "MP3 8 kHz");
					break;
				case 15: // 
					trace("soundFormat", "Device-specific sound");
					break;
			}
			
			/*
			SoundRate  UB [2]  Sampling rate. The following values are defined: 
			*/
			switch(soundRate)
			{
				case 0: // 
					trace("soundRate", "5.5 kHz");
					break;
				case 1: // 
					trace("soundRate", "11 kHz");
					break;
				case 2: // 
					trace("soundRate", "22 kHz");
					break;
				case 3: // 
					trace("soundRate", "44 kHz");
					break;
			}
			
			/*
			SoundSize  UB [1]  Size of each audio sample. This parameter only pertains to 
			uncompressed formats. Compressed formats always decode to 16 bits internally.  
			*/
			switch(soundSize)
			{
				case 0: // 
					trace("soundSize", "8-bit samples");
					break;
				case 1: // 
					trace("soundSize", "16-bit samples");
					break;
			}
			
			/*
			SoundType  UB [1]  Mono or stereo sound 
			*/
			switch(soundType)
			{
				case 0: // 
					trace("soundType", "Mono sound");
					break;
				case 1: // 
					trace("soundType", "Stereo sound");
					break;
			}
		}
		
		private function parseVideoTagData(data:ByteArray):void
		{
			/*
			Frame Type  UB [4]  Type of video frame. The following values are defined: 
			*/
			var firstByte:uint = data.readUnsignedByte();
			var frameType:uint = firstByte >> 4;
			var codecID:uint = firstByte & 0xF;
			switch(frameType)
			{
				case 1: // 
					trace("frameType", "key frame (for AVC, a seekable frame)");
					break;
				case 2: // 
					trace("frameType", "inter frame (for AVC, a non-seekable frame)");
					break;
				case 3: // 
					trace("frameType", "disposable inter frame (H.263 only)");
					break;
				case 4: // 
					trace("frameType", "generated key frame (reserved for server use only)");
					break;
				case 5: // 
					trace("frameType", "video info/command frame");
					break;
			}
			
			/*
			CodecID  UB [4]  Codec Identifier. The following values are defined: 
			*/
			switch(codecID)
			{
				case 2: // 
					trace("codecID", "Screen video");
					break;
				case 3: // 
					trace("codecID", "On2 VP6");
					break;
				case 4: // 
					trace("codecID", "On2 VP6 with alpha channel");
					break;
				case 5: // 
					trace("codecID", "Screen video version 2 ");
					break;
				case 6: // 
					trace("codecID", "Screen video version 2 ");
					break;
				case 7: // 
					trace("codecID", "AVC");
					/*
					AVCPacketType  IF CodecID == 7 
					UI8 
					The following values are defined: 
					0 = AVC sequence header 
					1 = AVC NALU 
					2 = AVC end of sequence (lower level NALU sequence ender is not required or supported)  
					*/
					var avcPacketType:uint = data.readUnsignedByte();
					switch(avcPacketType)
					{
						case 0: // 
							trace("AVCPacketType", "AVC sequence header");
							break;
						case 1: // 
							trace("AVCPacketType", "AVC NALU");
							/*
							CompositionTime SI24 (IF CodecID == 7)
							IF AVCPacketType == 1  Composition time offset  
							ELSE  0 
							See ISO 14496-12, 8.15.3 for an explanation of composition 
							times. The offset in an FLV file is always in milliseconds.  
							*/
							var compositionTime:uint = data.readUnsignedShort() << 8 + data.readUnsignedByte();
							trace("CompositionTime", compositionTime);
							break;
						case 2: // 
							trace("AVCPacketType", "AVC end of sequence");
							break;
					}
					
					break;
			}
		}
		
		
		private var metadata:Dictionary = new Dictionary();
		/**
		 * // script tag value starts after 1(tagtype)+3(datasize)+3(timestamp)+1(stampext)+3(streamid) = 11.
		 * @param tag
		 */		
		private function parseMetaData(tag:ByteArray):void
		{
			getPair(tag);
			
			if(tag.bytesAvailable > 0)
				parseMetaData(tag);
		}
		
		private function getPair(tag:ByteArray, kType:int=-1):*
		{
			if(kType == -1)
				kType = tag.readUnsignedByte();
			var kLen:uint = tag.readUnsignedShort();
			var k:String = tag.readUTFBytes(kLen);
			var vType:uint = tag.readUnsignedByte();
			var vSize:uint = 0;
			var v:*;
			/*
			Type  UI8  Type of the ScriptDataValue.  
			*/
			switch(vType)
			{
				case 0: // 0 = Number  Double
					v = tag.readDouble();
					trace("ScriptData", "Number", v);
					break;
				case 1: // 1 = Boolean  UI8
					v = tag.readBoolean();
					trace("ScriptData", "Boolean", v);
					break;
				case 2: // 2 = String 
					/*
					StringLength  UI16  StringData length in bytes. 
					StringData  STRING  String data, up to 65535 bytes, with no terminating NUL  
					*/
					vSize = tag.readUnsignedShort();
					v = tag.readUTFBytes(vSize);
					trace("ScriptData", "String", v);
					break;
				case 3: // 3 = Object 
					// TODO
					trace("ScriptData", "Object");
					break;
				case 4: // 4 = MovieClip (reserved, not supported) 
					trace("ScriptData", "MovieClip (reserved, not supported)");
					break;
				case 5: // 5 = Null 
					trace("ScriptData", "Null");
					break;
				case 6: // 6 = Undefined 
					trace("ScriptData", "Undefined");
					break;
				case 7: // 7 = Reference 
					trace("ScriptData", "Reference");
					break;
				case 8: // 8 = ECMA array. 
					/* 
					e.g. key(len, string) value(type, [size], [value]).
					ObjectEndMarker  UI8 [3]  Shall be 0, 0, 9  
					*/
					trace("ScriptData", "ECMA array", "length", tag.readUnsignedInt());
					v = "ECMA Array";
					var arrayEnd:uint = tag.readUnsignedShort()<<8 + tag.readUnsignedByte();
					while(arrayEnd != 9)
					{
						tag.position -= 3;
						getPair(tag, 2);
						arrayEnd = tag.readUnsignedShort()<<8 + tag.readUnsignedByte();
					}
					break;
				case 9: // 9 = Object end marker 
					trace("ScriptData", "ObjectEndMarker");
					break;
				case 10: // 10 = Strict array 
					trace("ScriptData", "Strict array");
					break;
				case 11: // 11 = Date 
					trace("ScriptData", "Date");
					break;
				case 12: // 12 = Long string, UI32.
					trace("ScriptData", "Long string");
					break;
			}
			trace("ScriptData", k + " : " + v);
			metadata[k] = v ;
			return {k:v} ;
		}
		
		
		private function parseECMAArray(bytes:ByteArray, type:int=-1):void
		{
			
		}
		
	}
}