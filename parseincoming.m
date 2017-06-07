
% user config values
serialPort = 'COM5';


% connect and open the serial port
s = serial(serialPort, 'BaudRate', 115200);
s.BytesAvailableFcnCount = 2;
s.BytesAvailableFcnMode = 'byte';
s.BytesAvailableFcn = @availTest;
fopen(s);


pause(1);

%%
% send a start command
% % need to send 2 bytes for a start command
% fwrite(s, 0);  % the command type
% fwrite(s, 0);  % the axis of control

sendCommand(s, 'start');

% sendCommand(s, 'move', 'Axis', 'elevation', ...
%                                'Direction', 'clockwise', ...
%                                'NumSteps', 8);

%%

sendCommand(s, 'stop');

%%


% this for now just loops through and waits for 5 messages
%readSignalStrengthMessage(s);


%%
% close the connection
fclose(s);