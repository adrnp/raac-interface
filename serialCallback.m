function [] = serialCallback(obj, event, figureObj)

% don't even try to parse if there is no data there!
if (obj.BytesAvailable <= 0)
    return;
end

% required values
SYNC_1 = hex2dec('A0');
SYNC_2 = hex2dec('B1');

% message IDS
MSG_ID_MEASUREMENT = 0;
MSG_ID_STATUS = 1;
MSG_ID_POSITION = 2;
msgId = 0;  % the current message being parsed

% message lengths
MSG_LEN_MEASUREMENT = 17;  % length of the measurement message
MSG_LEN_STATUS = 5;  % length of the status message
MSG_LEN_POSITION = 9;

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
allValues = zeros(1,100);
avIndex = 1;

% loop through reading the data as long as there is data available
while (obj.BytesAvailable > 0)
    % read in a byte
    [c, count] = fread(obj, 1, 'uint8');
    
    % end the loop if there is no data coming in
    if count == 0
        fprintf('no more bytes to read\n');
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
                case MSG_ID_POSITION
                    state = PARSE_MSG;
                    msgLen = MSG_LEN_POSITION;
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
                        handleMeasurement(buf, figureObj);
                    case MSG_ID_STATUS
                        handleStatus(buf, figureObj);
                    case MSG_ID_POSITION
                        handlePosition(buf, figureObj)
                end
            end
    end
    
end
%allValues


function [] = handleMeasurement(buf, figObj)
handles = guidata(figObj);
measInfo = handles.measurementInfo;

% extract the data from the buffer
timestamp = typecast(buf(1:4), 'uint32');
measIndex = buf(5);
signalStrength = typecast(buf(6:9), 'single');
azimuth = cast(typecast(buf(10:13), 'int32'), 'double');
elevation = cast(typecast(buf(14:17), 'int32'), 'double');

% fprintf('Az: %f (%3.6f) \t El: %f (%3.6f)\n', azimuth, azimuth/1e6, elevation, elevation/1e6);

azimuth = azimuth/1e6;
elevation = elevation/1e6;

% find the index for the azimuth
[~, azi] = min(abs(azimuth - measInfo.azimuth));
[~, eli] = min(abs(elevation - measInfo.elevation));
measInfo.measurements(azi, eli, measIndex) = signalStrength;
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

    % plot the el = 90 plot
%     axes(handles.axes1);
    figure(1);
%     handles.axes1 = plot(handles.axes1, deg2rad(measInfo.azimuth), mean(measInfo.measurements(:,1,:),3), 'x');
    polarplot(deg2rad(measInfo.azimuth), mean(measInfo.measurements(:,end,:),3), 'x-');
    title('sweep at el = 0');
    ax = gca;
    ax.ThetaDir = 'clockwise';
    ax.ThetaZeroLocation = 'top';
%     handles.axes1 = gca;
%     handles.axes1.ThetaDir = 'clockwise';
%     handles.axes1.ThetaZeroLocation = 'top';

    % plot the az = 0 plot
%     axes(handles.axes2);
    figure(2);
%     handles.axes2 = plot(handles.axes2, deg2rad(measInfo.elevation), mean(measInfo.measurements(1,:,:),3), 'x');
    polarplot(deg2rad(measInfo.elevation), mean(measInfo.measurements(1,:,:),3), 'x-');
    title('sweep at az = 0');
    ax = gca;
    ax.ThetaDir = 'clockwise';
    ax.ThetaZeroLocation = 'top';
%     handles.axes2 = gca;
%     handles.axes2.ThetaDir = 'clockwise';
%     handles.axes2.ThetaZeroLocation = 'top';

    % plot the current slice (so at the current elevation, all the
    % azimuths)
    figure(3);
    polarplot(deg2rad(measInfo.azimuth), mean(measInfo.measurements(:,eli,:), 3), 'x-');
    title('current azimuth sweep');
    ax = gca;
    ax.ThetaDir = 'clockwise';
    ax.ThetaZeroLocation = 'top';

    % TODO: 3D plot

    % update the axes
    guidata(figObj, handles);
    pause(0.01);
end

% update the stored measurement info (in the handles)
handles.measurementInfo = measInfo;
guidata(figObj, handles);



function [] = handleStatus(buf, figObj)

% get the handles for the GUI
handles = guidata(figObj);

STATUS_RUNNING = 0;
STATUS_PAUSED = 1;
STATUS_FINISHED = 2;

% extract the data from the buffer
timestamp = typecast(buf(1:4), 'uint32');
status = buf(5);

switch status
    case STATUS_RUNNING
        % TODO: need to figure out if should do something here...
        return;
        
    case STATUS_PAUSED
        % enable the buttons to send data, since this is the wakeup message
        set(handles.button_start_stop, 'Enable', 'On');
        set(handles.button_send_step_config, 'Enable', 'On');
        fprintf('no longer running\n');
        
    case STATUS_FINISHED
        % update the state of the script
        data = get(handles.button_start_stop, 'UserData');
        data.running = false;
        data.started = false;
        set(handles.button_start_stop, 'UserData', data);
        
        % update the UI as needed
        set(handles.button_start_stop, 'String', 'Start');
        set(handles.button_pause, 'Enable', 'Off');
        guidata(figObj, handles);
end



function [] = handlePosition(buf, figObj)

% get the handles for the GUI
handles = guidata(figObj);

timestamp = typecast(buf(1:4), 'uint32');
axis = buf(5);
position = cast(typecast(buf(6:9), 'int32'), 'double');

% fprintf('Axis: %d\t%f (%3.6f)\n', axis, position, position/1e6);

position = position/1e6;

switch axis
    case 1  % azimuth
        set(handles.text_azimuth, 'String', num2str(position));
    case 2  % elevation
        set(handles.text_elevation, 'String', num2str(position));
end



