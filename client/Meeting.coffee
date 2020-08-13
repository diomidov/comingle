import React, {useState, useEffect, useContext} from 'react'
import {Switch, Route, useParams, useLocation} from 'react-router-dom'
import FlexLayout from './FlexLayout'
import {useTracker} from 'meteor/react-meteor-data'
import {FontAwesomeIcon} from '@fortawesome/react-fontawesome'
import {faDoorOpen} from '@fortawesome/free-solid-svg-icons'

import {AppSettings} from './App'
import RoomList from './RoomList'
import Room from './Room'
import {Rooms} from '/lib/rooms'
import {Presence} from '/lib/presence'
import {validId} from '/lib/id'
import usePresenceId from './lib/usePresenceId'

initModel = ->
  model = FlexLayout.Model.fromJson
    global:
      borderEnableDrop: false
    borders: [
      type: 'border'
      location: 'left'
      selected: 0
      children: [
        id: 'roomsTab'
        type: 'tab'
        name: "Meeting Rooms"
        component: 'RoomList'
        enableClose: false
        enableDrag: false
      ]
    ]
    layout:
      id: 'root'
      type: 'row'
      weight: 100
      children: []
  model.setOnAllowDrop (dragNode, dropInfo) ->
    return false if dropInfo.node.getId() == 'roomsTabSet' and dropInfo.location != FlexLayout.DockLocation.RIGHT
    #return false if dropInfo.node.getType() == 'border'
    #return false if dragNode.getParent()?.getType() == 'border'
    true
  model

export default Meeting = ->
  {meetingId} = useParams()
  [model, setModel] = useState initModel
  [currentTabSet, setCurrentTabSet] = useState null
  location = useLocation()
  {loading, rooms} = useTracker ->
    sub = Meteor.subscribe 'meeting', meetingId
    loading: not sub.ready()
    rooms: Rooms.find().fetch()
  useEffect ->
    for room in rooms
      if model.getNodeById room._id
        model.doAction FlexLayout.Actions.updateNodeAttributes room._id,
          name: room.title
    undefined
  , [rooms]
  useEffect ->
    if location.hash and validId id = location.hash[1..]
      unless model.getNodeById id
        tab =
          id: id
          type: 'tab'
          name: Rooms.findOne(id)?.title ? id
          component: 'Room'
        if currentTabSet? and model.getNodeById currentTabSet
          model.doAction FlexLayout.Actions.addNode tab,
            currentTabSet, FlexLayout.DockLocation.CENTER, -1
        else
          model.doAction FlexLayout.Actions.addNode tab,
            'root', FlexLayout.DockLocation.RIGHT
          setCurrentTabSet model.getNodeById(id).getParent().getId()
      model.doAction FlexLayout.Actions.selectTab id
      updatePresence()
    undefined
  , [location]
  presenceId = usePresenceId()
  {name} = useContext AppSettings
  updatePresence = ->
    presence =
      id: presenceId
      meeting: meetingId
      name: name
      rooms:
        visible: []
        invisible: []
    model.visitNodes (node) ->
      if node.getType() == FlexLayout.TabNode.TYPE and
         node.getId() != 'roomsTab'
        if node.getParent()?.getSelectedNode?() == node
          presence.rooms.visible.push node.getId()
        else
          presence.rooms.invisible.push node.getId()
    current = Presence.findOne
      id: presenceId
      meeting: meetingId
    unless current? and current.name == presence.name and
           current?.rooms?.visible?.toString?() ==
           presence.rooms.visible.toString() and
           current?.rooms?.invisible?.toString?() ==
           presence.rooms.invisible.toString()
      Meteor.call 'presenceUpdate', presence
  useEffect updatePresence, [name]
  onAction = (action) ->
    setTimeout updatePresence, 0
    switch action.type
      when FlexLayout.Actions.SET_ACTIVE_TABSET
        ## RoomList is now in border, no longer tabset
        #unless action.data.tabsetNode == 'roomsTabSet'
        setCurrentTabSet action.data.tabsetNode
      when FlexLayout.Actions.RENAME_TAB
        ## Sanitize room title and push to other users
        action.data.text = action.data.text.trim()
        return unless action.data.text  # prevent empty title
        Meteor.call 'roomEdit',
          id: action.data.node
          title: action.data.text
    action
  factory = (tab) ->
    switch tab.getComponent()
      when 'Room' then <Room loading={loading} roomId={tab.getId()}/>
      when 'RoomList' then <RoomList loading={loading}/>
  iconFactory = (tab) ->
    <FontAwesomeIcon icon={faDoorOpen}/>
  <FlexLayout.Layout model={model} factory={factory} iconFactory={iconFactory}
   onAction={onAction}/>