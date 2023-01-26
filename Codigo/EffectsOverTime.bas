Attribute VB_Name = "EffectsOverTime"
Option Explicit

Private LastUpdateTime As Long
Private UniqueIdCounter As Long
Private ActiveEffects() As IBaseEffectOverTime
Private ActiveEffectCount As Integer
Const ACTIVE_EFFECTS_MIN_SIZE As Integer = 500

Const INITIAL_POOL_SIZE = 200
Private EffectPools() As t_EffectOverTimeList

Public Sub InitializePools()
On Error GoTo InitializePools_Err
    Dim i As Integer
    Dim j As Integer
100 ReDim EffectPools(1 To e_EffectOverTimeType.EffectTypeCount - 1) As t_EffectOverTimeList
102 For i = 1 To e_EffectOverTimeType.EffectTypeCount - 1
104     ReDim EffectPools(i).EffectList(INITIAL_POOL_SIZE) As IBaseEffectOverTime
106     For j = 0 To INITIAL_POOL_SIZE
108         Call AddEffect(EffectPools(i), InstantiateEOT(i))
110     Next j
    Next i
    Exit Sub
InitializePools_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.InitializePools", Erl)
End Sub

Public Sub UpdateEffectOverTime()
On Error GoTo Update_Err
    Dim CurrTime As Long
    Dim ElapsedTime As Long
100 CurrTime = GetTickCount()
102 If CurrTime < LastUpdateTime Then ' GetTickCount can overflow se we take care of that
104     ElapsedTime = 0
    Else
106     ElapsedTime = CurrTime - LastUpdateTime
    End If
108 LastUpdateTime = CurrTime
    
    
    Dim i As Integer
200 Do While i < ActiveEffectCount
202     If UpdateEffect(i, ElapsedTime) Then
204         i = i + 1
        End If
    Loop
    Exit Sub
Update_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.Update", Erl)
End Sub

Private Function UpdateEffect(ByVal Index As Integer, ByVal ElapsedTime As Long) As Boolean
On Error GoTo UpdateEffect_Err
    'this should never happend but it covers us for breaking all effects if something goes wrong
100 If ActiveEffects(Index) Is Nothing Then
102     UpdateEffect = True
        Exit Function
    End If
104 ActiveEffects(Index).Update (ElapsedTime)
106 If ActiveEffects(Index).RemoveMe Then
108     If ActiveEffects(Index).TargetIsValid Then
110         If ActiveEffects(Index).TargetRefType = eUser Then
112             Call RemoveEffect(UserList(ActiveEffects(Index).TargetArrayIndex).EffectOverTime, ActiveEffects(Index))
114         ElseIf ActiveEffects(Index).TargetRefType = eNpc Then
116             Call RemoveEffect(NpcList(ActiveEffects(Index).TargetArrayIndex).EffectOverTime, ActiveEffects(Index))
            End If
        End If
120     Call ReleaseEffect(ActiveEffects(Index))
124     Set ActiveEffects(Index) = ActiveEffects(ActiveEffectCount - 1)
130     Set ActiveEffects(ActiveEffectCount - 1) = Nothing
132     ActiveEffectCount = ActiveEffectCount - 1
134     UpdateEffect = False
    Else
138     UpdateEffect = True
    End If
    Exit Function
UpdateEffect_Err:
    Call TraceError(Err.Number, Err.Description, "EffectsOverTime.UpdateEffect", Erl)
    Set ActiveEffects(Index) = Nothing
    UpdateEffect = True
End Function

Public Sub CreateEffect(ByVal sourceIndex As Integer, ByVal sourceType As e_ReferenceType, _
                                  ByVal TargetIndex As Integer, ByVal TargetType As e_ReferenceType, _
                                  ByVal EffectIndex As Integer)
On Error GoTo CreateEffect_Err
    Dim EffectType As e_EffectOverTimeType
100 EffectType = EffectOverTime(EffectIndex).Type
    Select Case EffectType
        Case e_EffectOverTimeType.eHealthModifier
102         Dim Dot As UpdateHpOverTime
104         Set Dot = GetEOT(EffectType)
106         UniqueIdCounter = UniqueIdCounter + 1
108         Call Dot.Setup(sourceIndex, sourceType, TargetIndex, TargetType, EffectIndex, UniqueIdCounter)
110         Call AddEffectToUpdate(Dot)
112         If TargetType = eUser Then
114             Call AddEffect(UserList(TargetIndex).EffectOverTime, Dot)
116         ElseIf TargetType = eNpc Then
118             Call AddEffect(NpcList(TargetIndex).EffectOverTime, Dot)
            End If
    End Select
    Exit Sub
CreateEffect_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.CreateEffect", Erl)
End Sub

Private Function InstantiateEOT(ByVal EffectType As e_EffectOverTimeType) As IBaseEffectOverTime
    Select Case EffectType
        Case e_EffectOverTimeType.eHealthModifier
            Set InstantiateEOT = New UpdateHpOverTime
    End Select
End Function

Private Function GetEOT(ByVal EffectType As e_EffectOverTimeType) As IBaseEffectOverTime
On Error GoTo GetEOT_Err
100 Set GetEOT = Nothing
102 If EffectPools(EffectType).EffectCount = 0 Then
104     Set GetEOT = InstantiateEOT(EffectType)
        Exit Function
    End If
108 Set GetEOT = EffectPools(EffectType).EffectList(EffectPools(EffectType).EffectCount - 1)
120 Set EffectPools(EffectType).EffectList(EffectPools(EffectType).EffectCount - 1) = Nothing
126 EffectPools(EffectType).EffectCount = EffectPools(EffectType).EffectCount - 1
    Exit Function
GetEOT_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.GetEOT", Erl)
End Function

Private Sub ReleaseEffect(ByRef Effect As IBaseEffectOverTime)
    Call AddEffect(EffectPools(Effect.TypeId), Effect)
End Sub

Public Sub AddEffectToUpdate(ByRef Effect As IBaseEffectOverTime)
On Error GoTo AddEffectToUpdate_Err
100 If Not IsArrayInitialized(ActiveEffects) Then
108     ReDim ActiveEffects(ACTIVE_EFFECTS_MIN_SIZE) As IBaseEffectOverTime
    ElseIf ActiveEffectCount >= UBound(ActiveEffects) Then
120     ReDim Preserve ActiveEffects(ActiveEffectCount * 1.2) As IBaseEffectOverTime
    End If
130 Set ActiveEffects(ActiveEffectCount) = Effect
132 ActiveEffectCount = ActiveEffectCount + 1
    Exit Sub
AddEffectToUpdate_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.AddEffectToUpdate", Erl)
End Sub

Public Sub AddEffect(ByRef EffectList As t_EffectOverTimeList, ByRef Effect As IBaseEffectOverTime)
On Error GoTo AddEffect_Err
100 If Not IsArrayInitialized(EffectList.EffectList) Then
104     ReDim EffectList.EffectList(ACTIVE_EFFECT_LIST_SIZE) As IBaseEffectOverTime
    ElseIf EffectList.EffectCount >= UBound(EffectList.EffectList) Then
108     ReDim Preserve EffectList.EffectList(EffectList.EffectCount * 1.2) As IBaseEffectOverTime
    End If
116 Set EffectList.EffectList(EffectList.EffectCount) = Effect
120 EffectList.EffectCount = EffectList.EffectCount + 1
    Exit Sub
AddEffect_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.AddEffect", Erl)
End Sub

Public Sub RemoveEffect(ByRef EffectList As t_EffectOverTimeList, ByRef Effect As IBaseEffectOverTime)
On Error GoTo RemoveEffect_Err
    Dim i As Integer
100 For i = 0 To EffectList.EffectCount - 1
106     If EffectList.EffectList(i).UniqueId() = Effect.UniqueId() Then
110         Set EffectList.EffectList(i) = ActiveEffects(EffectList.EffectCount - 1)
118         Set EffectList.EffectList(EffectList.EffectCount - 1) = Nothing
120         EffectList.EffectCount = EffectList.EffectCount - 1
            Exit Sub
        End If
    Next i
    Exit Sub
RemoveEffect_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.RemoveEffect", Erl)
End Sub

Public Function FindEffectOnTarget(ByVal CasterIndex As Integer, ByRef EffectList As t_EffectOverTimeList, ByVal EffectId As Integer) As IBaseEffectOverTime
On Error GoTo FindEffectOnTarget_Err
100 Set FindEffectOnTarget = Nothing
102 Dim EffectLimit As e_EOTTargetLimit
104 EffectLimit = EffectOverTime(EffectId).Limit
106 Dim i As Integer
108 If EffectLimit = e_EOTTargetLimit.eAny Then
        Exit Function
    End If
120 For i = 0 To EffectList.EffectCount - 1
126     If EffectList.EffectList(i).EotId = EffectId Then
130         If EffectLimit = eSingle Then
132             Set FindEffectOnTarget = EffectList.EffectList(i)
                Exit Function
            Else
140             If EffectList.EffectList(i).CasterRefType = eUser Then
142                 If EffectList.EffectList(i).CasterUserId = UserList(CasterIndex).ID Then
144                     Set FindEffectOnTarget = EffectList.EffectList(i)
                        Exit Function
                    End If
150             ElseIf EffectList.EffectList(i).CasterRefType = eNpc Then
152                 If EffectList.EffectList(i).CasterIsValid Then
154                     Set FindEffectOnTarget = EffectList.EffectList(i)
                        Exit Function
                    End If
                End If
            End If
        End If
    Next i
    Exit Function
FindEffectOnTarget_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.FindEffectOnTarget", Erl)
End Function

Public Sub ClearEffectList(ByRef EffectList As t_EffectOverTimeList, Optional ByVal Filter As e_EffectType = e_EffectType.eAny)
On Error GoTo ClearEffectList_Err
    Dim i As Integer
100 Do While i < EffectList.EffectCount
102     If Filter = e_EffectType.eAny Or Filter = EffectList.EffectList(i).EffectType Then
104         EffectList.EffectList(i).RemoveMe = True
106         Set EffectList.EffectList(i) = ActiveEffects(EffectList.EffectCount - 1)
108         Set EffectList.EffectList(EffectList.EffectCount - 1) = Nothing
110         EffectList.EffectCount = EffectList.EffectCount - 1
        Else
112         i = i + 1
        End If
    Loop
Exit Sub
ClearEffectList_Err:
      Call TraceError(Err.Number, Err.Description, "EffectsOverTime.ClearEffectList", Erl)
End Sub
