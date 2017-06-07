function [] = readSignalStrengthMessageGUI(s, hObject, handles)

% required values
SYNC_1 = hex2dec('A0');
SYNC_2 = hex2dec('B1');
MSG_LEN = 16;

PARSE_SYNC_1 = 1;
PARSE_SYNC_2 = 2;
PARSE_MSG = 3;

% for testing do this for 5 messages
N = 0;

state = PARSE_SYNC_1;
msg = uint8(zeros(1, 16));
msgIndex = 1;

allValues = zeros(1, 100);
avIndex = 1;

data = get(handles.button_start_stop, 'UserData');

azimuth = 0:1.8:360;
elevation = 0:1.8:360;
if isfield(handles, 'measurements')
    measurements = handles.measurements;
else
    measurements = zeros(length(azimuth), length(elevation), 10);
end

lastAzimuth = 0;
lastElevation = 0;
ssi = 1;
while (data.running)
    [c, count] = fread(s, 1, 'uint8');
    if count == 0
        % end the loop if there is no data coming in
        break;
    end
    allValues(avIndex) = c;
    avIndex = avIndex + 1;
    
    switch (state)
        case PARSE_SYNC_1
            
            if (c == SYNC_1)
                state = PARSE_SYNC_2;
            end
            
        case PARSE_SYNC_2
            
            if (c == SYNC_2)
                state = PARSE_MSG;
                msgIndex = 1;
            end
            
        case PARSE_MSG
            msg(msgIndex) = c;
            msgIndex = msgIndex + 1;
            
            if (msgIndex > MSG_LEN)
                state = PARSE_SYNC_1;
                N = N + 1;
                
                % DEBUG - output the parsed data
                parsed.timestamp = typecast(msg(1:4), 'uint32');
                parsed.signalStrength = typecast(msg(5:8), 'single');
                parsed.azimuth = typecast(msg(9:12), 'single');
                parsed.elevation = typecast(msg(13:16), 'single');
                %display(parsed)
                
                % find the index for the azimuth
                [~, azi] = min(abs(parsed.azimuth - azimuth));
                [~, eli] = min(abs(parsed.elevation - elevation));
                measurements(azi, eli, ssi) = parsed.signalStrength;
                ssi = ssi + 1;
                
                % update the display every time we have a new angle
                if parsed.azimuth ~= lastAzimuth || parsed.elevation ~= lastElevation
                    lastAzimuth = parsed.azimuth;
                    lastElevation = parsed.elevation;
                    
                    % reset the index for storing the measurements
                    ssi = 1;
                    
                    % display the values in the text boxes
                    set(handles.text_azimuth, 'String', num2str(parsed.azimuth));
                    set(handles.text_elevation, 'String', num2str(parsed.elevation));
                    set(handles.text_signal_strength, 'String', num2str(parsed.signalStrength));
                    
                    % plot the az = 0 plot
                    axes(handles.axes1);
                    polarplot(deg2rad(azimuth), mean(measurements(1,:,:),3), 'x');
                    handles.axes1 = gca;
                    handles.axes1.ThetaDir = 'clockwise';
                    handles.axes1.ThetaZeroLocation = 'top';
                    
                    
                    % plot the el = 0 plot
                    axes(handles.axes2);
                    polarplot(deg2rad(elevation), mean(measurements(:,1,:),3), 'x');
                    handles.axes2 = gca;
                    handles.axes2.ThetaDir = 'clockwise';
                    handles.axes2.ThetaZeroLocation = 'top';
                    
                    % update the axes
                    guidata(hObject, handles);
                    pause(0.01);
                end
            end
    end
    data = get(handles.button_start_stop, 'UserData');
end

% update the handles
handles.measurements = measurements;
guidata(hObject, handles);

fprintf('done\n');