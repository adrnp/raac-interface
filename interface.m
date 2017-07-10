function varargout = interface(varargin)
% INTERFACE MATLAB code for interface.fig
%      INTERFACE, by itself, creates a new INTERFACE or raises the existing
%      singleton*.
%
%      H = INTERFACE returns the handle to a new INTERFACE or the handle to
%      the existing singleton*.
%
%      INTERFACE('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in INTERFACE.M with the given input arguments.
%
%      INTERFACE('Property','Value',...) creates a new INTERFACE or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before interface_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to interface_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help interface

% Last Modified by GUIDE v2.5 10-Jul-2017 11:51:34

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @interface_OpeningFcn, ...
                   'gui_OutputFcn',  @interface_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before interface is made visible.
function interface_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to interface (see VARARGIN)

% Choose default command line output for interface
handles.output = hObject;

% set some "global" values that will be needed between functions
handles.serialOpen = false;  % state of the serial port connection

% Update handles structure
guidata(hObject, handles);

% set the dropdown to have the desired list of options
% TODO: should pull this from a settings file or something
rgroup_el_step_size_SelectionChangedFcn(hObject, eventdata, handles)
rgroup_az_step_size_SelectionChangedFcn(hObject, eventdata, handles)

% refresh the list of available com ports
button_serial_refresh_Callback(hObject, eventdata, handles);


% UIWAIT makes interface wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = interface_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in button_start_stop.
function button_start_stop_Callback(hObject, eventdata, handles)
% hObject    handle to button_start_stop (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

data = get(hObject, 'UserData');

isStarted = false;
if isfield(data, 'started')
    isStarted = data.started;
end

if isStarted
    sendCommand(handles.s, 'stop');
    data.started = false;
    data.running = false;
    set(hObject, 'String', 'Start');
    set(hObject, 'UserData', data);
    set(handles.button_pause, 'Enable', 'Off');
else
    % send the configuration first
    sendConfiguration(hObject, eventdata, handles);
    
    % set up the measurement values based on the configs
    selected = get(handles.dropdown_az_meas_inc, 'Value');
    selectSet = get(handles.dropdown_az_meas_inc, 'String');
    stepSize = str2double(selectSet(selected));
    
    startAngle = get(handles.slider_az_start_angle, 'Value');
    endAngle = get(handles.slider_az_end_angle, 'Value');
    
    measInfo.azimuth = startAngle:stepSize:endAngle;
    
    selected = get(handles.dropdown_el_meas_inc, 'Value');
    selectSet = get(handles.dropdown_el_meas_inc, 'String');
    stepSize = str2double(selectSet(selected));
    
    startAngle = get(handles.slider_el_start_angle, 'Value');
    endAngle = get(handles.slider_el_end_angle, 'Value');
    
    % get which axis to start
    runAxis = 'both';
    if get(handles.check_az_enabled, 'Value') == 0
        runAxis = 'elevation';
    elseif get(handles.check_el_enabled, 'Value') == 0
        runAxis = 'azimuth';
    end
    
    if startAngle < endAngle
        measInfo.elevation = startAngle:stepSize:endAngle;
    else
        measInfo.elevation = startAngle:-stepSize:endAngle;
    end
    
    NMeas = round(str2double(get(handles.edit_num_measurements, 'String')));
    
    measInfo.lastAz = 0;
    measInfo.lastEl = 0;
    measInfo.ssi = 1;
    measInfo.measurements = zeros(length(measInfo.azimuth), length(measInfo.elevation), NMeas);
    handles.measurementInfo = measInfo;
    guidata(hObject, handles);
    
    % send the start command
    sendCommand(handles.s, 'start', 'NumMeasurements', NMeas, ...
                                    'Axis', runAxis);
    
    % update running state
    data.started = true;
    data.running = true;
    set(hObject, 'UserData', data);
    
    % update UI as needed
    set(hObject, 'String', 'Stop');
    set(handles.button_pause, 'Enable', 'On');
    set(handles.button_save, 'Enable', 'On');
    pause(0.01);
    
    % need to start running the function here...
%     readIncomingGUI(handles.s, hObject, handles);
end

% --- Executes on button press in button_pause.
function button_pause_Callback(hObject, eventdata, handles)
% hObject    handle to button_pause (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

data = get(hObject, 'UserData');
runData = get(handles.button_start_stop, 'UserData');

isPaused = false;
if isfield(data, 'paused')
    isPaused = data.paused;
end

if isPaused
    sendCommand(handles.s, 'start');
    data.paused = false;
    set(hObject, 'String', 'Pause');
    set(hObject, 'UserData', data);
    
    runData.running = true;
    set(handles.button_start_stop, 'UserData', runData);
    pause(0.01);
    
    % need to restart the reading of the data
    readIncomingGUI(handles.s, hObject, handles);
else
    sendCommand(handles.s, 'pause');
    data.paused = true;
    set(hObject, 'String', 'Restart');
    set(hObject, 'UserData', data);
    
    runData.running = false;
    set(handles.button_start_stop, 'UserData', runData);
end

function sendConfiguration(hObject, eventdata, handles)
% function to send the configuration to the arduino
% configuration is all of the selection from all of the configuration named
% boxes in the UI

% read and send the elevation config values
quarter = get(handles.radio_el_step_quarter, 'Value');
half = get(handles.radio_el_step_half, 'Value');
full = get(handles.radio_el_step_full, 'Value');
stepSize = '1/8';
if quarter == 1
    stepSize = '1/4';
elseif half == 1
    stepSize = '1/2';
elseif full == 1
    stepSize = '1';
end
measStr = get(handles.dropdown_el_meas_inc, 'String');
measVal = get(handles.dropdown_el_meas_inc, 'Value');
measInc = str2double(measStr(measVal));

% also need to read the slides to know the start/end angles for each axis
startAngle = get(handles.slider_el_start_angle, 'Value');
endAngle = get(handles.slider_el_end_angle, 'Value');

sendCommand(handles.s, 'configure', 'Axis', 'Elevation',...
                                    'StepSize', stepSize, ...
                                    'MeasurementIncrement', measInc, ...
                                    'Start', startAngle, ...
                                    'End', endAngle);

% read and send the azimuth config values
quarter = get(handles.radio_az_step_quarter, 'Value');
half = get(handles.radio_az_step_half, 'Value');
full = get(handles.radio_az_step_full, 'Value');
stepSize = '1/8';
if quarter == 1
    stepSize = '1/4';
elseif half == 1
    stepSize = '1/2';
elseif full == 1
    stepSize = '1';
end
measStr = get(handles.dropdown_az_meas_inc, 'String');
measVal = get(handles.dropdown_az_meas_inc, 'Value');
measInc = str2double(measStr(measVal));

% also need to read the slides to know the start/end angles for each axis
startAngle = get(handles.slider_az_start_angle, 'Value');
endAngle = get(handles.slider_az_end_angle, 'Value');

sendCommand(handles.s, 'configure', 'Axis', 'Azimuth',...
                                    'StepSize', stepSize, ...
                                    'MeasurementIncrement', measInc, ...
                                    'Start', startAngle, ...
                                    'End', endAngle);

% --- Executes on selection change in dropdown_el_meas_inc.
function dropdown_el_meas_inc_Callback(hObject, eventdata, handles)
% hObject    handle to dropdown_el_meas_inc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dropdown_el_meas_inc contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dropdown_el_meas_inc
selectedInd = get(hObject, 'Value');
selectSet = get(hObject, 'String');
val = str2double(selectSet(selectedInd));

upperVal = 1.8;
if val > upperVal
    upperVal = val;
end

% update the az sliders
set(handles.slider_el_start_angle, 'SliderStep', [val/90 upperVal/90]);
set(handles.slider_el_end_angle, 'SliderStep', [val/90 upperVal/90]);

% --- Executes during object creation, after setting all properties.
function dropdown_el_meas_inc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dropdown_el_meas_inc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in radio_el_step_quarter.
function radio_el_step_quarter_Callback(hObject, eventdata, handles)
% hObject    handle to radio_el_step_quarter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radio_el_step_quarter


% --- Executes when selected object is changed in rgroup_el_step_size.
function rgroup_el_step_size_SelectionChangedFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in rgroup_el_step_size 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

eigth = get(handles.radio_el_step_eigth, 'Value');
quarter = get(handles.radio_el_step_quarter, 'Value');
half = get(handles.radio_el_step_half, 'Value');

if eigth == 1
    set(handles.dropdown_el_meas_inc, 'String', {'0.225', '0.45', '0.675', '0.9', '1.125', '1.35', '1.575', '1.8', '2.025', '2.25', '2.475', '2.7', '2.925', '3.15', '3.375', '3.6', '3.825', '4.05', '4.275', '4.5', '4.725', '4.95', '5.175', '5.4', '5.625'});
elseif quarter == 1
    set(handles.dropdown_el_meas_inc, 'String', {'0.45', '0.9', '1.35', '1.8', '2.25', '2.7', '3.15', '3.6', '4.05', '4.5', '4.95', '5.4', '5.85', '6.3', '6.75', '7.2', '7.65', '8.1', '8.55', '9', '9.45', '9.9', '10.35', '10.8', '11.25'});
elseif half == 1
    set(handles.dropdown_el_meas_inc, 'String', {'0.9', '1.8', '2.7', '3.6', '4.5', '5.4', '6.3', '7.2', '8.1', '9', '9.9', '10.8', '11.7', '12.6', '13.5', '14.4', '15.3', '16.2', '17.1', '18', '18.9', '19.8', '20.7', '21.6', '22.5'});
else
    set(handles.dropdown_el_meas_inc, 'String', {'1.8', '3.6', '5.4', '7.2', '9', '10.8', '12.6', '14.4', '16.2', '18', '19.8', '21.6', '23.4', '25.2', '27', '28.8', '30.6', '32.4', '34.2', '36', '37.8', '39.6', '41.4', '43.2', '45'});
end

selectedInd = get(handles.dropdown_el_meas_inc, 'Value');
selectSet = get(handles.dropdown_el_meas_inc, 'String');
val = str2double(selectSet(selectedInd));

upperVal = 1.8;
if val > upperVal
    upperVal = val;
end

% update the az sliders
set(handles.slider_el_start_angle, 'SliderStep', [val/90 upperVal/90]);
set(handles.slider_el_end_angle, 'SliderStep', [val/90 upperVal/90]);


% --- Executes on selection change in dropdown_serial_port.
function dropdown_serial_port_Callback(hObject, eventdata, handles)
% hObject    handle to dropdown_serial_port (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dropdown_serial_port contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dropdown_serial_port
items = get(hObject,'String');
ind = get(hObject,'Value');
port = items{ind};
handles.s = serial(port, 'BaudRate', 115200);
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function dropdown_serial_port_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dropdown_serial_port (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in button_connect.
function button_connect_Callback(hObject, eventdata, handles)
% hObject    handle to button_connect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if (handles.serialOpen)
    % close the port
    fclose(handles.s);
    
    % set the flag for the port being closed
    handles.serialOpen = false;
    guidata(hObject, handles);
    
    % change buttons and control appropriately
    set(hObject, 'String', 'Connect');
    set(handles.dropdown_serial_port, 'Enable', 'On');
    set(handles.button_start_stop, 'Enable', 'Off');
    set(handles.button_pause, 'Enable', 'Off');
else
    % configure the callback
    handles.s.BytesAvailableFcnCount = 2;
    handles.s.BytesAvailableFcnMode = 'byte';
    handles.s.BytesAvailableFcn = {@serialCallback, handles.figure1};
    
    % open the port
    fopen(handles.s);
    
    % set the flag for the port being open
    handles.serialOpen = true;
    guidata(hObject, handles);
    
    % change buttons and control appropriately - only serial related
    % buttons
    set(hObject, 'String', 'Disconnect');
    set(handles.dropdown_serial_port, 'Enable', 'Off');
    
    % see the serial callback for enabling the buttons to interact with the
    % arduino, as we first need to hear a wakeup message
    
    % reset the texts to 0
    set(handles.text_azimuth, 'String', '0');
    set(handles.text_elevation, 'String', '0');
    set(handles.text_signal_strength, 'String', '0');
end




% --- Executes on button press in button_serial_refresh.
function button_serial_refresh_Callback(hObject, eventdata, handles)
% hObject    handle to button_serial_refresh (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get the list of available com ports
details = instrhwinfo('serial');
ports = details.AvailableSerialPorts;

% set the dropdown list options to the available com ports
set(handles.dropdown_serial_port, 'String', ports);


% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);

% close the port if it is present, just to be safe
if isfield(handles, 's')
    fclose(handles.s);
end


% --- Executes on selection change in dropdown_az_meas_inc.
function dropdown_az_meas_inc_Callback(hObject, eventdata, handles)
% hObject    handle to dropdown_az_meas_inc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns dropdown_az_meas_inc contents as cell array
%        contents{get(hObject,'Value')} returns selected item from dropdown_az_meas_inc
selectedInd = get(hObject, 'Value');
selectSet = get(hObject, 'String');
val = str2double(selectSet(selectedInd));

upperVal = 1.8;
if val > upperVal
    upperVal = val;
end

% update the az sliders
set(handles.slider_az_start_angle, 'SliderStep', [val/360 upperVal/360]);
set(handles.slider_az_end_angle, 'SliderStep', [val/360 upperVal/360]);

% --- Executes during object creation, after setting all properties.
function dropdown_az_meas_inc_CreateFcn(hObject, eventdata, handles)
% hObject    handle to dropdown_az_meas_inc (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes when selected object is changed in rgroup_az_step_size.
function rgroup_az_step_size_SelectionChangedFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in rgroup_az_step_size 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

eigth = get(handles.radio_az_step_eigth, 'Value');
quarter = get(handles.radio_az_step_quarter, 'Value');
half = get(handles.radio_az_step_half, 'Value');


if eigth == 1
	set(handles.dropdown_az_meas_inc, 'String', {'0.225', '0.45', '0.675', '0.9', '1.125', '1.35', '1.575', '1.8', '2.025', '2.25', '2.475', '2.7', '2.925', '3.15', '3.375', '3.6', '3.825', '4.05', '4.275', '4.5', '4.725', '4.95', '5.175', '5.4', '5.625'});
elseif quarter == 1
	set(handles.dropdown_az_meas_inc, 'String', {'0.45', '0.9', '1.35', '1.8', '2.25', '2.7', '3.15', '3.6', '4.05', '4.5', '4.95', '5.4', '5.85', '6.3', '6.75', '7.2', '7.65', '8.1', '8.55', '9', '9.45', '9.9', '10.35', '10.8', '11.25'});
elseif half == 1
	set(handles.dropdown_az_meas_inc, String', {'0.9', '1.8', '2.7', '3.6', '4.5', '5.4', '6.3', '7.2', '8.1', '9', '9.9', '10.8', '11.7', '12.6', '13.5', '14.4', '15.3', '16.2', '17.1', '18', '18.9', '19.8', '20.7', '21.6', '22.5'});
else
	set(handles.dropdown_az_meas_inc, 'String', {'1.8', '3.6', '5.4', '7.2', '9', '10.8', '12.6', '14.4', '16.2', '18', '19.8', '21.6', '23.4', '25.2', '27', '28.8', '30.6', '32.4', '34.2', '36', '37.8', '39.6', '41.4', '43.2', '45'});
end

selectedInd = get(handles.dropdown_az_meas_inc, 'Value');
selectSet = get(handles.dropdown_az_meas_inc, 'String');
val = str2double(selectSet(selectedInd));

upperVal = 1.8;
if val > upperVal
    upperVal = val;
end

% update the az sliders
set(handles.slider_az_start_angle, 'SliderStep', [val/360 upperVal/360]);
set(handles.slider_az_end_angle, 'SliderStep', [val/360 upperVal/360]);


% --- Executes on button press in button_save.
function button_save_Callback(hObject, eventdata, handles)
% hObject    handle to button_save (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

filename = inputdlg('Enter Filename (without .mat extension)');
filename = strcat(filename{1}, '.mat');

measurementInfo = {};
if isfield(handles, 'measurementInfo')
    measurementInfo = handles.measurementInfo;
end

save(filename, 'measurementInfo');


% --- Executes on button press in check_el_enabled.
function check_el_enabled_Callback(hObject, eventdata, handles)
% hObject    handle to check_el_enabled (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of check_el_enabled


% --- Executes on button press in check_az_enabled.
function check_az_enabled_Callback(hObject, eventdata, handles)
% hObject    handle to check_az_enabled (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of check_az_enabled


% --- Executes on slider movement.
function slider_az_end_angle_Callback(hObject, eventdata, handles)
% hObject    handle to slider_az_end_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% need to know the step size to be able to round appropriately
selected = get(handles.dropdown_az_meas_inc, 'Value');
selectSet = get(handles.dropdown_az_meas_inc, 'String');
stepSize = str2double(selectSet(selected));

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_az_end_angle, 'String', val);


% --- Executes during object creation, after setting all properties.
function slider_az_end_angle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_az_end_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_az_start_angle_Callback(hObject, eventdata, handles)
% hObject    handle to slider_az_start_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
% need to know the step size to be able to round appropriately
selected = get(handles.dropdown_az_meas_inc, 'Value');
selectSet = get(handles.dropdown_az_meas_inc, 'String');
stepSize = str2double(selectSet(selected));

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_az_start_angle, 'String', val);

% --- Executes during object creation, after setting all properties.
function slider_az_start_angle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_az_start_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_el_start_angle_Callback(hObject, eventdata, handles)
% hObject    handle to slider_el_start_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% need to know the step size to be able to round appropriately
selected = get(handles.dropdown_el_meas_inc, 'Value');
selectSet = get(handles.dropdown_el_meas_inc, 'String');
stepSize = str2double(selectSet(selected));

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_el_start_angle, 'String', val);

% --- Executes during object creation, after setting all properties.
function slider_el_start_angle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_el_start_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_el_end_angle_Callback(hObject, eventdata, handles)
% hObject    handle to slider_el_end_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

% need to know the step size to be able to round appropriately
selected = get(handles.dropdown_el_meas_inc, 'Value');
selectSet = get(handles.dropdown_el_meas_inc, 'String');
stepSize = str2double(selectSet(selected));

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_el_end_angle, 'String', val);

% --- Executes during object creation, after setting all properties.
function slider_el_end_angle_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_el_end_angle (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end



function edit_num_measurements_Callback(hObject, eventdata, handles)
% hObject    handle to edit_num_measurements (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit_num_measurements as text
%        str2double(get(hObject,'String')) returns contents of edit_num_measurements as a double


% --- Executes during object creation, after setting all properties.
function edit_num_measurements_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit_num_measurements (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in btn_elstep_left_small.
function btn_elstep_left_small_Callback(hObject, eventdata, handles)
% hObject    handle to btn_elstep_left_small (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'elevation', ...
                               'Direction', 'counterclockwise', ...
                               'NumSteps', 1);

% --- Executes on button press in btn_elstep_left_big.
function btn_elstep_left_big_Callback(hObject, eventdata, handles)
% hObject    handle to btn_elstep_left_big (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'elevation', ...
                               'Direction', 'counterclockwise', ...
                               'NumSteps', 8);

% --- Executes on button press in btn_azstep_left_small.
function btn_azstep_left_small_Callback(hObject, eventdata, handles)
% hObject    handle to btn_azstep_left_small (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'azimuth', ...
                               'Direction', 'counterclockwise', ...
                               'NumSteps', 1);

% --- Executes on button press in btn_azstep_left_big.
function btn_azstep_left_big_Callback(hObject, eventdata, handles)
% hObject    handle to btn_azstep_left_big (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'azimuth', ...
                               'Direction', 'counterclockwise', ...
                               'NumSteps', 8);

% --- Executes on button press in btn_elstep_right_small.
function btn_elstep_right_small_Callback(hObject, eventdata, handles)
% hObject    handle to btn_elstep_right_small (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'elevation', ...
                               'Direction', 'clockwise', ...
                               'NumSteps', 1);

% --- Executes on button press in btn_elstep_right_big.
function btn_elstep_right_big_Callback(hObject, eventdata, handles)
% hObject    handle to btn_elstep_right_big (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'elevation', ...
                               'Direction', 'clockwise', ...
                               'NumSteps', 8);

% --- Executes on button press in btn_azstep_right_small.
function btn_azstep_right_small_Callback(hObject, eventdata, handles)
% hObject    handle to btn_azstep_right_small (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'azimuth', ...
                               'Direction', 'clockwise', ...
                               'NumSteps', 1);

% --- Executes on button press in btn_azstep_right_big.
function btn_azstep_right_big_Callback(hObject, eventdata, handles)
% hObject    handle to btn_azstep_right_big (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
sendCommand(handles.s, 'move', 'Axis', 'azimuth', ...
                               'Direction', 'clockwise', ...
                               'NumSteps', 8);


% --- Executes on slider movement.
function slider_el_control_Callback(hObject, eventdata, handles)
% hObject    handle to slider_el_control (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

stepSize = 1.8;

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_el_control, 'String', val);

% --- Executes during object creation, after setting all properties.
function slider_el_control_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_el_control (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on slider movement.
function slider_az_control_Callback(hObject, eventdata, handles)
% hObject    handle to slider_az_control (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider
stepSize = 1.8;

% just need to see if the value is closer to below or above it
val = get(hObject, 'Value');
offset = mod(val, stepSize);
val = val - offset;

set(hObject, 'Value', val);
set(handles.text_az_control, 'String', val);

% --- Executes during object creation, after setting all properties.
function slider_az_control_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider_az_control (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in button_set_manual.
function button_set_manual_Callback(hObject, eventdata, handles)
% hObject    handle to button_set_manual (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% read the sliders to know the angles
elAngle = get(handles.slider_el_control, 'Value');
azAngle = get(handles.slider_az_control, 'Value');

sendCommand(handles.s, 'moveto', 'Axis', 'Elevation',...
                                    'Start', elAngle);
                                
sendCommand(handles.s, 'moveto', 'Axis', 'Azimuth',...
                                    'Start', azAngle);


% --- Executes on button press in button_phase_set.
function button_phase_set_Callback(hObject, eventdata, handles)
% hObject    handle to button_phase_set (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% read the user inputted values
phases = zeros(3,1);
phases(1) = str2double(get(handles.edit_phase_a0, 'String'));
phases(2) = str2double(get(handles.edit_phase_a1, 'String'));
phases(3) = str2double(get(handles.edit_phase_a2, 'String'));

% need to ensure the values are proper
% allowed [0, 360), multiples of 1.4
phases(phases < 0) = phases(phases < 0) + 360;
phases(phases >= 360) = phases(phases >= 360) - 360;
phases = round(phases/1.4)*1.4;

% display the adjusted values
set(handles.edit_phase_a0, 'String', phases(1));
set(handles.edit_phase_a1, 'String', phases(2));
set(handles.edit_phase_a2, 'String', phases(3));

% now send the command
sendCommand(handles.s, 'setphase', 'Phases', phases);


% --- Executes when selected object is changed in rgroup_detector.
function rgroup_detector_SelectionChangedFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in rgroup_detector 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% when a selection is made, send that selection over to the arduino
type = 'serial';
if get(handles.radio_analog_rf, 'Value') == 1
    type = 'analog';
end
sendCommand(handles.s, 'detector', 'Type', type);
