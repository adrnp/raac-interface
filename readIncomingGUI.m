function [] = readIncomingGUI(s, hObject, handles)
% reads incoming bytes over the serial connection and then parses the
% message according to the message type


% required values
SYNC_1 = hex2dec('A0');
SYNC_2 = hex2dec('B1');

% message IDS
MSG_ID_MEASUREMENT = 0;
MSG_ID_STATUS = 1;
msgId = 0;  % the current message being parsed

% message lengths
MSG_LEN_MEASUREMENT = 16;  % length of the measurement message
MSG_LEN_STATUS = 5;  % length of the status message

MSG_LEN_MAX = 16;  % maximum message length - basically the buffer size
msgLen = 0;  % the length of the message to save to the buffer

% parsing state values
PARSE_SYNC_1 = 1;
PARSE_SYNC_2 = 2;
PARSE_MSG_ID = 3;
PARSE_MSG = 4;
state = PARSE_SYNC_1;  % the current state we are in

% the message number we are on
N = 0;

% the message buffer information
buf = uint8(zeros(1, MSG_LEN_MAX));
bufIndex = 1;

% for debugging - store the last 100 bytes of data
allValues = zeros(1, 100);
avIndex = 1;

% get the measurement info
measInfo = handles.measurementInfo;

data = get(handles.button_start_stop, 'UserData');
while (data.running)
    % read in a byte
    [c, count] = fread(s, 1, 'uint8');
    
    % end the loop if there is no data coming in
    if count == 0
        break;
    end
    
    % DEBUG - save the last 100 bytes
    allValues(avIndex) = c;
    avIndex = avIndex + 1;
    if avIndex > 100
        avIndex = 1;
    end
    
    % parse the byte according to the current parsing state
    switch (state)
        case PARSE_SYNC_1
            
            if (c == SYNC_1)
                state = PARSE_SYNC_2;
            end
            
        case PARSE_SYNC_2
            
            if (c == SYNC_2)
                state = PARSE_MSG_ID;
            end
           
        case PARSE_MSG_ID
            
            % set the next parsing state based on the message to parse
            msgId = c;
            switch (msgId)
                case MSG_ID_MEASUREMENT
                    state = PARSE_MSG;
                    msgLen = MSG_LEN_MEASUREMENT;
                case MSG_ID_STATUS
                    state = PARSE_MSG;
                    msgLen = MSG_LEN_STATUS;
                otherwise
                    % go back to waiting for a new message
                    state = PARSE_SYNC_1;
            end
            bufIndex = 1;

        case PARSE_MSG
            buf(bufIndex) = c;
            bufIndex = bufIndex + 1;
            
            % once the entire message has been read, handle it accordingly
            if (bufIndex > msgLen)
                N = N + 1;
                state = PARSE_SYNC_1;
                switch (msgId)
                    case MSG_ID_MEASUREMENT
                        measInfo = handleMeasurement(buf, measInfo, hObject, handles);
                    case MSG_ID_STATUS
                        handleStatus(buf, hObject, handles);
                end
            end
    end
    data = get(handles.button_start_stop, 'UserData');
end

% update the handles
handles.measurementInfo = measInfo;
guidata(hObject, handles);

fprintf('done\n');


function [measInfo] = handleMeasurement(buf, measInfo, hObject, handles)

% extract the data from the buffer
timestamp = typecast(buf(1:4), 'uint32');
signalStrength = typecast(buf(5:8), 'single');
azimuth = typecast(buf(9:12), 'single');
elevation = typecast(buf(13:16), 'single');

% find the index for the azimuth
[~, azi] = min(abs(azimuth - measInfo.azimuth));
[~, eli] = min(abs(elevation - measInfo.elevation));
measInfo.measurements(azi, eli, measInfo.ssi) = signalStrength;
measInfo.ssi = measInfo.ssi + 1;

% update the display every time we have a new angle
if azimuth ~= measInfo.lastAz || elevation ~= measInfo.lastEl
    measInfo.lastAz = azimuth;
    measInfo.lastEl = elevation;

    % reset the index for storing the measurements
    measInfo.ssi = 1;

    % display the values in the text boxes
    set(handles.text_azimuth, 'String', num2str(azimuth));
    set(handles.text_elevation, 'String', num2str(elevation));
    set(handles.text_signal_strength, 'String', num2str(signalStrength));

%     % plot the az = 0 plot
%     axes(handles.axes1);
%     polarplot(deg2rad(azimuth), mean(measInfo.measurements(1,:,:),3), 'x');
%     handles.axes1 = gca;
%     handles.axes1.ThetaDir = 'clockwise';
%     handles.axes1.ThetaZeroLocation = 'top';
% 
%     % plot the el = 0 plot
%     axes(handles.axes2);
%     polarplot(deg2rad(elevation), mean(measInfo.measurements(:,1,:),3), 'x');
%     handles.axes2 = gca;
%     handles.axes2.ThetaDir = 'clockwise';
%     handles.axes2.ThetaZeroLocation = 'top';

    % update the axes
    guidata(hObject, handles);
    pause(0.01);
end



function [] = handleStatus(buf, hObject, handles)

STATUS_RUNNING = 0;
STATUS_PAUSED = 1;
STATUS_FINISHED = 2;

% extract the data from the buffer
timestamp = typecast(buf(1:4), 'uint32');
status = buf(5);

switch status
    case STATUS_RUNNING
    case STATUS_PAUSED
        return;
    case STATUS_FINISHED
        % update the state of the script
        data = get(handles.button_start_stop, 'UserData');
        data.running = false;
        data.started = false;
        set(handles.button_start_stop, 'UserData', data);
        
        % update the UI as needed
        set(handles.button_start_stop, 'String', 'Start');
        set(handles.button_pause, 'Enable', 'Off');
        guidata(hObject, handles);
end

