{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Utility Window

    Simple window intended for use in sending and processing of custom messages,
    or when there is a need for invisible window that is capable of reacting to
    messages sent or posted to it.

    Can be used in a non-main thread as long as you call method ProcessMessages
    at least once...

      When you call it with parameter WaitForMessage set to false, it will
      return immediately after processing all queued messages, so it is your
      responsibility to repeat the call later if you want to continue reacting
      to posted messages.

      When called with WaitForMessage set to true, the function does not
      return until WM_QUIT message is posted to the queue or you call method
      BreakProcessing inside message handling.
      If the processing is hanging on a wait to a message, and you want to
      break it, post custom message from different thread that will break this
      waiting and react to it in the handler by calling BreakProcessing.

    WARNING - the window must be created and managed (eg. call to method
              ProcessMessages) in the same thread where you want to process
              the messages, otherwise it will not work!

  Version 1.3 (2019-10-02)

  Last change 2019-10-02

  ©2015-2019 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.UtilityWindow

  Dependencies:
    AuxTypes       - github.com/TheLazyTomcat/Lib.AuxTypes
    AuxClasses     - github.com/TheLazyTomcat/Lib.AuxClasses
    MulticastEvent - github.com/TheLazyTomcat/Lib.MulticastEvent
    WndAlloc       - github.com/TheLazyTomcat/Lib.WndAlloc
    StrRect        - github.com/TheLazyTomcat/Lib.StrRect
  * SimpleCPUID    - github.com/TheLazyTomcat/Lib.SimpleCPUID

    SimpleCPUID is required only when PurePascal symbol is not defined.

===============================================================================}
unit UtilityWindow;

{$IF not(defined(WINDOWS) or defined(MSWINDOWS))}
  {$MESSAGE FATAL 'Unsupported operating system.'}
{$IFEND}

{$IFDEF FPC}
  {$MODE Delphi}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}

interface

uses
  Windows, Messages, SysUtils,
  AuxClasses, MulticastEvent;

type
  TUWException = class(Exception);

{
  Msg

    Contains currently processed message.

  Handled

    When it is false on entry, it indicates the message was not yet handled,
    when true it was handled by at least one, and possibly more, handlers.

    The handler should set it to true when it does something with the message,
    but it is not mandatory. Never set it to false (it has no effect).

  Sent

    Indicates that the processed message was sent, rather than posted.

    It means the handling of the message was not called from method
    ProcessMessages of the utility window, but directly by the system.

    This also means calling BreakProcessing has no immediate effect.
}
  TMessageCallback = procedure(var Msg: TMessage; var Handled: Boolean; Sent: Boolean);
  TMessageEvent    = procedure(var Msg: TMessage; var Handled: Boolean; Sent: Boolean) of object;

{===============================================================================
    TMulticastMessageEvent - class declaration
===============================================================================}

  TMulticastMessageEvent = class(TMulticastEvent)
  public
    Function IndexOf(const Handler: TMessageCallback): Integer; reintroduce; overload;
    Function IndexOf(const Handler: TMessageEvent): Integer; reintroduce; overload;
    Function Add(Handler: TMessageCallback; AllowDuplicity: Boolean = False): Integer; reintroduce; overload;
    Function Add(Handler: TMessageEvent; AllowDuplicity: Boolean = False): Integer; reintroduce; overload;
    Function Remove(const Handler: TMessageCallback): Integer; reintroduce; overload;
    Function Remove(const Handler: TMessageEvent): Integer; reintroduce; overload;
    procedure Call(var Msg: TMessage; var Handled: Boolean; Sent: Boolean); reintroduce;
  end;

{===============================================================================
    TUtilityWindow - class declarationn
===============================================================================}

  TUtilityWindow = class(TCustomObject)
  private
    fWindowHandle:  HWND;
    fContinue:      Boolean;
    fOnMessage:     TMulticastMessageEvent;
  protected
    procedure WndProc(var Msg: TMessage); virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure BreakProcessing; virtual;
    procedure ProcessMessages(WaitForMessage: Boolean = False); virtual;
    property WindowHandle: HWND read fWindowHandle;
    property OnMessage: TMulticastMessageEvent read fOnMessage;
  end;

implementation

uses
  WndAlloc;

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W5036:={$WARN 5036 OFF}} // Local variable "$1" does not seem to be initialized
{$ENDIF}

{===============================================================================
    TMulticastMessageEvent - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TMulticastMessageEvent - public methods
-------------------------------------------------------------------------------}

Function TMulticastMessageEvent.IndexOf(const Handler: TMessageCallback): Integer;
begin
Result := inherited IndexOf(TCallback(Handler));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TMulticastMessageEvent.IndexOf(const Handler: TMessageEvent): Integer;
begin
Result := inherited IndexOf(TEvent(Handler));
end;

//------------------------------------------------------------------------------

Function TMulticastMessageEvent.Add(Handler: TMessageCallback; AllowDuplicity: Boolean = False): Integer;
begin
Result := inherited Add(TCallback(Handler),AllowDuplicity);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TMulticastMessageEvent.Add(Handler: TMessageEvent; AllowDuplicity: Boolean = False): Integer;
begin
Result := inherited Add(TEvent(Handler),AllowDuplicity);
end;

//------------------------------------------------------------------------------

Function TMulticastMessageEvent.Remove(const Handler: TMessageCallback): Integer;
begin
Result := inherited Remove(TCallback(Handler));
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function TMulticastMessageEvent.Remove(const Handler: TMessageEvent): Integer;
begin
Result := inherited Remove(TEvent(Handler));
end;

//------------------------------------------------------------------------------

procedure TMulticastMessageEvent.Call(var Msg: TMessage; var Handled: Boolean; Sent: Boolean);
var
  i:            Integer;
  EntryHandled: Boolean;
begin
Handled := False;
For i := LowIndex to HighIndex do
  begin
    EntryHandled := Handled;
    If Entries[i].IsMethod then
      TMessageEvent(Entries[i].HandlerMethod)(Msg,EntryHandled,Sent)
    else
      TMessageCallback(Entries[i].HandlerProcedure)(Msg,EntryHandled,Sent);
    If EntryHandled then
      Handled := True;
  end;
end;

{===============================================================================
    TUtilityWindow - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TUtilityWindow - protected methods
-------------------------------------------------------------------------------}

procedure TUtilityWindow.WndProc(var Msg: TMessage);
var
  Handled:  Boolean;
begin
Handled := False;
fOnMessage.Call(Msg,Handled,InSendMessage);
If not Handled then
  Msg.Result := DefWindowProc(fWindowHandle,Msg.Msg,Msg.wParam,Msg.lParam);
end;

{-------------------------------------------------------------------------------
    TUtilityWindow - public methods
-------------------------------------------------------------------------------}

constructor TUtilityWindow.Create;
begin
inherited;
fOnMessage := TMulticastMessageEvent.Create(Self);
fWindowHandle := WndAlloc.AllocateHWND(WndProc);
end;

//------------------------------------------------------------------------------

destructor TUtilityWindow.Destroy;
begin
WndAlloc.DeallocateHWND(fWindowHandle);
fOnMessage.Free;
inherited;
end;

//------------------------------------------------------------------------------

procedure TUtilityWindow.BreakProcessing;
begin
fContinue := False;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5036{$ENDIF}
procedure TUtilityWindow.ProcessMessages(WaitForMessage: Boolean = False);
var
  Msg:    TMsg;
  GetRes: Integer;

  Function GetMessageWrapper(out IntResult: Integer): Boolean;
  begin
    Result := False;
    If fContinue then
      begin
        IntResult := Integer(GetMessage(Msg,fWindowHandle,0,0));
        Result := IntResult <> 0;
      end
    else IntResult := 0;
  end;

begin
fContinue := True;
If WaitForMessage then
  begin
    while GetMessageWrapper(GetRes) do
      begin
        If GetRes <> -1 then
          begin
            TranslateMessage(Msg);
            DispatchMessage(Msg);
          end
        else raise TUWException.CreateFmt('TUtilityWindow.ProcessMessages: Failed to retrieve a message (0x%.8x).',[GetLastError]);
      end;
  end
else
  begin
    while PeekMessage(Msg,fWindowHandle,0,0,PM_REMOVE) and fContinue do
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
  end;
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

end.
