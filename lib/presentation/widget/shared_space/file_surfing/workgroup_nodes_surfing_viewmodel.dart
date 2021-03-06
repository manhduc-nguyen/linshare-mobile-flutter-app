// LinShare is an open source filesharing software, part of the LinPKI software
// suite, developed by Linagora.
//
// Copyright (C) 2020 LINAGORA
//
// This program is free software: you can redistribute it and/or modify it under the
// terms of the GNU Affero General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later version,
// provided you comply with the Additional Terms applicable for LinShare software by
// Linagora pursuant to Section 7 of the GNU Affero General Public License,
// subsections (b), (c), and (e), pursuant to which you must notably (i) retain the
// display in the interface of the “LinShare™” trademark/logo, the "Libre & Free" mention,
// the words “You are using the Free and Open Source version of LinShare™, powered by
// Linagora © 2009–2020. Contribute to Linshare R&D by subscribing to an Enterprise
// offer!”. You must also retain the latter notice in all asynchronous messages such as
// e-mails sent with the Program, (ii) retain all hypertext links between LinShare and
// http://www.linshare.org, between linagora.com and Linagora, and (iii) refrain from
// infringing Linagora intellectual property rights over its trademarks and commercial
// brands. Other Additional Terms apply, see
// <http://www.linshare.org/licenses/LinShare-License_AfferoGPL-v3.pdf>
// for more details.
// This program is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for
// more details.
// You should have received a copy of the GNU Affero General Public License and its
// applicable Additional Terms for LinShare along with this program. If not, see
// <http://www.gnu.org/licenses/> for the GNU Affero General Public License version
//  3 and <http://www.linshare.org/licenses/LinShare-License_AfferoGPL-v3.pdf> for
//  the Additional Terms applicable to LinShare software.

import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:domain/domain.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:linshare_flutter_app/presentation/localizations/app_localizations.dart';
import 'package:linshare_flutter_app/presentation/model/file/presentation_file.dart';
import 'package:linshare_flutter_app/presentation/model/file/selectable_element.dart';
import 'package:linshare_flutter_app/presentation/model/file/work_group_document_presentation_file.dart';
import 'package:linshare_flutter_app/presentation/model/file/work_group_folder_presentation_file.dart';
import 'package:linshare_flutter_app/presentation/model/item_selection_type.dart';
import 'package:linshare_flutter_app/presentation/redux/actions/shared_space_action.dart';
import 'package:linshare_flutter_app/presentation/redux/actions/ui_action.dart';
import 'package:linshare_flutter_app/presentation/redux/online_thunk_action.dart';
import 'package:linshare_flutter_app/presentation/redux/states/app_state.dart';
import 'package:linshare_flutter_app/presentation/redux/states/ui_state.dart';
import 'package:linshare_flutter_app/presentation/util/router/app_navigation.dart';
import 'package:linshare_flutter_app/presentation/util/router/route_paths.dart';
import 'package:linshare_flutter_app/presentation/view/context_menu/context_menu_builder.dart';
import 'package:linshare_flutter_app/presentation/view/downloading_file/downloading_file_builder.dart';
import 'package:linshare_flutter_app/presentation/view/header/context_menu_header_builder.dart';
import 'package:linshare_flutter_app/presentation/view/header/more_action_bottom_sheet_header_builder.dart';
import 'package:linshare_flutter_app/presentation/view/header/simple_bottom_sheet_header_builder.dart';
import 'package:linshare_flutter_app/presentation/view/modal_sheets/confirm_modal_sheet_builder.dart';
import 'package:linshare_flutter_app/presentation/view/order_by/order_by_dialog_bottom_sheet.dart';
import 'package:linshare_flutter_app/presentation/widget/base/base_viewmodel.dart';
import 'package:linshare_flutter_app/presentation/widget/destination_picker/destination_picker_action/copy_destination_picker_action.dart';
import 'package:linshare_flutter_app/presentation/widget/destination_picker/destination_picker_action/negative_destination_picker_action.dart';
import 'package:linshare_flutter_app/presentation/widget/destination_picker/destination_picker_arguments.dart';
import 'package:linshare_flutter_app/presentation/widget/shared_space/file_surfing/workgroup_nodes_surfing_state.dart';
import 'package:linshare_flutter_app/presentation/widget/shared_space/file_surfing/workgroup_nodes_surfling_arguments.dart';
import 'package:linshare_flutter_app/presentation/widget/upload_file/destination_type.dart';
import 'package:open_file/open_file.dart' as open_file;
import 'package:permission_handler/permission_handler.dart';
import 'package:redux/src/store.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share/share.dart' as share_library;

class WorkGroupNodesSurfingViewModel extends BaseViewModel {
  final GetAllChildNodesInteractor _getAllChildNodesInteractor;
  final RemoveMultipleSharedSpaceNodesInteractor _removeMultipleSharedSpaceNodesInteractor;
  final CopyMultipleFilesToMySpaceInteractor _copyMultipleToMySpaceInteractor;
  final CopyMultipleFilesToSharedSpaceInteractor _copyMultipleFilesToSharedSpaceInteractor;
  final DownloadMultipleNodeIOSInteractor _downloadMultipleNodeIOSInteractor;
  final SearchWorkGroupNodeInteractor _searchWorkGroupNodeInteractor;
  final DownloadWorkGroupNodeInteractor _downloadWorkGroupNodeInteractor;
  final DownloadPreviewWorkGroupDocumentInteractor _downloadPreviewWorkGroupDocumentInteractor;
  final SortInteractor _sortInteractor;
  final GetSorterInteractor _getSorterInteractor;
  final SaveSorterInteractor _saveSorterInteractor;
  final AppNavigation _appNavigation;

  final BehaviorSubject<WorkGroupNodesSurfingState> _stateSubscription =
      BehaviorSubject.seeded(WorkGroupNodesSurfingState(null, [], FolderNodeType.normal,
          sorter: Sorter.fromOrderScreen(OrderScreen.sharedSpace)));
  StreamView<WorkGroupNodesSurfingState> get stateSubscription => _stateSubscription;

  WorkGroupNodesSurfingState get currentState => _stateSubscription.value;
  StreamSubscription _storeStreamSubscription;

  SearchQuery _searchQuery = SearchQuery('');
  SearchQuery get searchQuery  => _searchQuery;

  List<WorkGroupNode> _workGroupNodesList;

  WorkGroupNodesSurfingViewModel(
    Store<AppState> store,
    this._appNavigation,
    this._getAllChildNodesInteractor,
    this._removeMultipleSharedSpaceNodesInteractor,
    this._copyMultipleToMySpaceInteractor,
    this._copyMultipleFilesToSharedSpaceInteractor,
    this._downloadMultipleNodeIOSInteractor,
    this._searchWorkGroupNodeInteractor,
    this._downloadWorkGroupNodeInteractor,
    this._downloadPreviewWorkGroupDocumentInteractor,
    this._sortInteractor,
    this._getSorterInteractor,
    this._saveSorterInteractor
  ) : super(store) {
    _storeStreamSubscription = store.onChange.listen((event) {
      event.sharedSpaceState.viewState.fold(
         (failure) => null,
         (success) {
            if (success is SearchWorkGroupNodeNewQuery && event.uiState.searchState.searchStatus == SearchStatus.ACTIVE) {
              _search(success.searchQuery);
            } else if (success is DisableSearchViewState) {
              _stateSubscription.add(currentState.setWorkGroupNodesList(_workGroupNodesList, showLoading: false));
              _searchQuery = SearchQuery('');

            } else if (success is ClearWorkGroupNodesListViewState) {
              _stateSubscription.add(currentState.setWorkGroupNodesList([], showLoading: false));
            } else if (success is RemoveSharedSpaceNodeViewState ||
                success is RemoveAllSharedSpaceNodesSuccessViewState ||
                success is RemoveSomeSharedSpaceNodesSuccessViewState) {
              loadAllChildNodes();
            } else if (success is CreateSharedSpaceFolderViewState) {
              loadAllChildNodes();
            } else if (success is SharedSpaceViewState) {
              loadSorterAndAllChildNodes();
            }
      });
    });
  }

  void initial(WorkGroupNodesSurfingArguments input) {
    if (isInSearchState()) {
      store.dispatch(DisableSearchStateAction());
    }

    _stateSubscription.add(currentState.copyWith(
      node: input.folder,
      folderNodeType: input.folderType,
      sharedSpaceId: input.sharedSpaceNodeNested.sharedSpaceId,
    ));
  }

  @override
  void onDisposed() {
    cancelSelection();
    store.dispatch(DisableSearchStateAction());
    _storeStreamSubscription.cancel();
    _searchQuery = SearchQuery('');
    super.onDisposed();
  }

  void _search(SearchQuery searchQuery) {
    _searchQuery = searchQuery;
    if (searchQuery.value.isNotEmpty) {
      _searchDocumentAction(_workGroupNodesList, searchQuery);
    } else {
      _stateSubscription.add(currentState.copyWith(children: [], showLoading: false));
    }
  }

  void _searchDocumentAction(List<WorkGroupNode> workGroupNodes, SearchQuery searchQuery) async {
    if (isInSearchState()) {
      await _searchWorkGroupNodeInteractor.execute(workGroupNodes, searchQuery).then((result) => result.fold(
        (failure) => {
          _stateSubscription.add(currentState.copyWith(children: [], showLoading: false))
        },
        (success) => {
          _stateSubscription.add(currentState.setWorkGroupNodesList(success is SearchWorkGroupNodeSuccess ? success.workGroupNodesList : [], showLoading: false))
        })
      );
    }
  }

  bool isInSearchState() {
    return store.state.uiState.isInSearchState();
  }

  void loadAllChildNodes() async {
    _stateSubscription.add(currentState.copyWith(showLoading: true));

    final isRootFolder = currentState.folderNodeType == FolderNodeType.root;
    final result = await _getAllChildNodesInteractor.execute(
      isRootFolder
          ? currentState.sharedSpaceId
          : currentState.node.sharedSpaceId,
      parentId: isRootFolder ? null : currentState.node.workGroupNodeId,
    );

    result.fold(
      (failure) {
        _stateSubscription.add(currentState.copyWith(children: [], showLoading: false));
        _workGroupNodesList = [];
      },
      (success) {
        _workGroupNodesList = (success as GetChildNodesViewState).workGroupNodes;
        if (isInSearchState()) {
          _search(_searchQuery);
        } else {
          _stateSubscription.add(currentState.setWorkGroupNodesList(
            (success as GetChildNodesViewState).workGroupNodes,
            showLoading: false
          ));
        }
      },
    );

    store.dispatch(_sortFilesAction(currentState.sorter));
  }

  void openFolderContextMenu(BuildContext context, WorkGroupFolder workGroupFolder, List<Widget> actionTiles) {
    store.dispatch(_handleContextMenuFolderAction(context, workGroupFolder, actionTiles));
  }

  void openDocumentContextMenu(BuildContext context, WorkGroupDocument workGroupDocument, List<Widget> actionTiles, Widget footerAction) {
    store.dispatch(_handleContextMenuDocumentAction(context, workGroupDocument, actionTiles, footerAction));
  }

  ThunkAction<AppState> _handleContextMenuDocumentAction(
      BuildContext context, WorkGroupDocument workGroupDocument, List<Widget> actionTiles, Widget footerAction) {
    return (Store<AppState> store) async {
      ContextMenuBuilder(context)
        .addHeader(ContextMenuHeaderBuilder(
          Key('context_menu_header'),
          WorkGroupDocumentPresentationFile.fromWorkGroupDocument(workGroupDocument)).build())
        .addTiles(actionTiles)
        .addFooter(footerAction)
        .build();
      store.dispatch(SharedSpaceAction(Right(ContextMenuWorkGroupNodeViewState(workGroupDocument))));
    };
  }

  ThunkAction<AppState> _handleContextMenuFolderAction(
      BuildContext context, WorkGroupFolder workGroupFolder, List<Widget> actionTiles) {
    return (Store<AppState> store) async {
      ContextMenuBuilder(context)
        .addHeader(ContextMenuHeaderBuilder(
          Key('context_menu_header'),
          WorkGroupFolderPresentationFile.fromWorkGroupFolder(workGroupFolder)).build())
        .addTiles(actionTiles)
        .build();
      store.dispatch(SharedSpaceAction(Right(ContextMenuWorkGroupNodeViewState(workGroupFolder))));
    };
  }

  void removeWorkGroupNode(BuildContext context, List<WorkGroupNode> workGroupNodes,
      {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    _appNavigation.popBack();
    if (itemSelectionType == ItemSelectionType.multiple) {
      cancelSelection();
    }

    if (workGroupNodes != null && workGroupNodes.isNotEmpty) {
      final deleteTitle = AppLocalizations.of(context)
          .are_you_sure_you_want_to_delete_multiple(workGroupNodes.length, workGroupNodes.first.name);

      ConfirmModalSheetBuilder(_appNavigation)
          .key(Key('delete_work_group_node_confirm_modal'))
          .title(deleteTitle)
          .cancelText(AppLocalizations.of(context).cancel)
          .onConfirmAction(AppLocalizations.of(context).delete, () {
        _appNavigation.popBack();
        if (itemSelectionType == ItemSelectionType.multiple) {
          cancelSelection();
        }
        store.dispatch(_removeWorkGroupNodeAction(workGroupNodes));
      }).show(context);
    }
  }

  ThunkAction<AppState> _removeWorkGroupNodeAction(List<WorkGroupNode> workGroupNodes) {
    return (Store<AppState> store) async {
      await _removeMultipleSharedSpaceNodesInteractor.execute(workGroupNodes)
        .then((result) => result.fold(
          (failure) => store.dispatch(SharedSpaceAction(Left(failure))),
          (success) => store.dispatch(SharedSpaceAction(Right(success)))));
      loadAllChildNodes();
    };
  }

  void toggleSelectAllWorkGroupNodes() {
    if (_stateSubscription.value.isAllDocumentsSelected()) {
      _stateSubscription.add(currentState.unselectAllWorkGroupNodes());
    } else {
      _stateSubscription.add(currentState.selectAllWorkGroupNodes());
    }
  }

  void cancelSelection() {
    _stateSubscription.add(currentState.cancelSelectedWorkGroupNodes());
    store.dispatch(EnableUploadButtonAction());
  }

  void selectItem(SelectableElement<WorkGroupNode> selectedWorkGroupNode) {
    _stateSubscription.add(currentState.selectWorkGroupNode(selectedWorkGroupNode));
    store.dispatch(DisableUploadButtonAction());
  }

  void copyToMySpace(List<WorkGroupNode> workGroupNodes) {
    _appNavigation.popBack();
    store.dispatch(_copyToMySpaceAction(workGroupNodes));
  }

  OnlineThunkAction _copyToMySpaceAction(List<WorkGroupNode> workGroupNodes) {
    return OnlineThunkAction((Store<AppState> store) async {
      await _copyMultipleToMySpaceInteractor.execute(workGroupNodes: workGroupNodes)
        .then((result) => result.fold(
          (failure) => store.dispatch(SharedSpaceAction(Left(failure))),
          (success) => store.dispatch(SharedSpaceAction(Right(success)))));
    });
  }

  void exportFiles(BuildContext context, List<WorkGroupNode> workGroupNodes,
      {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    _appNavigation.popBack();
    if (itemSelectionType == ItemSelectionType.multiple) {
      cancelSelection();
    }
    final cancelToken = CancelToken();
    _showDownloadingFileDialog(context, workGroupNodes, cancelToken);
    store.dispatch(_exportFileAction(workGroupNodes, cancelToken));
  }

  void _showDownloadingFileDialog(BuildContext context, List<WorkGroupNode> workGroupNodes, CancelToken cancelToken) {
    final downloadMessage = workGroupNodes.length <= 1
        ? AppLocalizations.of(context).downloading_file(workGroupNodes.first.name)
        : AppLocalizations.of(context).downloading_files(workGroupNodes.length);

    showCupertinoDialog(
        context: context,
        builder: (_) => DownloadingFileBuilder(cancelToken, _appNavigation)
            .key(Key('downloading_file_dialog'))
            .title(AppLocalizations.of(context).preparing_to_export)
            .content(downloadMessage)
            .actionText(AppLocalizations.of(context).cancel)
            .build());
  }

  OnlineThunkAction _exportFileAction(List<WorkGroupNode> workGroupNodes, CancelToken cancelToken) {
    return OnlineThunkAction((Store<AppState> store) async {
      await _downloadMultipleNodeIOSInteractor.execute(workGroupNodes: workGroupNodes, cancelToken: cancelToken).then(
              (result) => result.fold(
                  (failure) => store.dispatch(_exportFileFailureAction(failure)),
                  (success) => store.dispatch(_exportFileSuccessAction(success))));
    });
  }

  ThunkAction<AppState> _exportFileSuccessAction(Success success) {
    return (Store<AppState> store) async {
      _appNavigation.popBack();
      store.dispatch(SharedSpaceAction(Right(success)));
      if (success is DownloadNodeIOSViewState) {
        await share_library.Share.shareFiles([Uri.decodeFull(success.filePath.path)]);
      } else if (success is DownloadNodeIOSAllSuccessViewState) {
        await share_library.Share.shareFiles(success.resultList
            .map((result) => Uri.decodeFull(
            ((result.getOrElse(() => null) as DownloadNodeIOSViewState).filePath.path)))
            .toList());
      } else if (success is DownloadNodeIOSHasSomeFilesFailureViewState) {
        await share_library.Share.shareFiles(success.resultList
            .map((result) => result.fold(
                (failure) => null,
                (success) => Uri.decodeFull(((success as DownloadNodeIOSViewState).filePath.path))))
            .toList());
      }
    };
  }

  ThunkAction<AppState> _exportFileFailureAction(Failure failure) {
    return (Store<AppState> store) async {
      if (failure is DownloadNodeIOSFailure &&
          !(failure.downloadFileException is CancelDownloadFileException)) {
        _appNavigation.popBack();
      }
      store.dispatch(SharedSpaceAction(Left(failure)));
    };
  }

  void downloadNodes(List<WorkGroupNode> nodes, {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    store.dispatch(_downloadNodeAction(nodes, itemSelectionType: itemSelectionType));
    _appNavigation.popBack();
    if (itemSelectionType == ItemSelectionType.multiple) {
      cancelSelection();
    }
  }

  OnlineThunkAction _downloadNodeAction(List<WorkGroupNode> nodes, {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    return OnlineThunkAction((Store<AppState> store) async {
      final status = await Permission.storage.status;
      switch (status) {
        case PermissionStatus.granted: _dispatchHandleDownloadAction(nodes, itemSelectionType: itemSelectionType);
        break;
        case PermissionStatus.permanentlyDenied:
          _appNavigation.popBack();
          break;
        default: {
          final requested = await Permission.storage.request();
          switch (requested) {
            case PermissionStatus.granted: _dispatchHandleDownloadAction(nodes, itemSelectionType: itemSelectionType);
              break;
            default: _appNavigation.popBack();
              break;
          }
        }
      }
    });
  }

  void _dispatchHandleDownloadAction(List<WorkGroupNode> nodes, {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    store.dispatch(_handleDownloadNodes(nodes));
  }

  OnlineThunkAction _handleDownloadNodes(List<WorkGroupNode> nodes) {
    return OnlineThunkAction((Store<AppState> store) async {
      await _downloadWorkGroupNodeInteractor.execute(nodes)
          .then((result) => result.fold(
              (failure) => store.dispatch(SharedSpaceAction(Left(failure))),
              (success) => store.dispatch(SharedSpaceAction(Right(success)))));
    });
  }

  void copyTo(BuildContext context, List<WorkGroupNode> nodes, List<DestinationType> availableDestinationTypes, {ItemSelectionType itemSelectionType = ItemSelectionType.single}) {
    _appNavigation.popBack();
    if (itemSelectionType == ItemSelectionType.multiple) {
      cancelSelection();
    }

    final cancelAction = NegativeDestinationPickerAction(context,
        label: AppLocalizations.of(context).cancel.toUpperCase());
    cancelAction.onDestinationPickerActionClick((_) => _appNavigation.popBack());

    final copyAction = CopyDestinationPickerAction(context);
    copyAction.onDestinationPickerActionClick((data) {
      if (data == DestinationType.mySpace) {
        copyToMySpace(nodes);
      }
      if (data is WorkGroupNodesSurfingArguments){
        _appNavigation.popBack();
        store.dispatch(_copyToWorkgroupAction(nodes, data));
      }
    });

    _appNavigation.push(RoutePaths.destinationPicker,
        arguments: DestinationPickerArguments(
            actionList: [copyAction, cancelAction],
            operator: Operation.copyTo,
            availableDestinationTypes: availableDestinationTypes
        ));
  }

  OnlineThunkAction _copyToWorkgroupAction(List<WorkGroupNode> nodes, WorkGroupNodesSurfingArguments workGroupNodesSurfingArguments) {
    return OnlineThunkAction((Store<AppState> store) async {
      final parentNodeId = workGroupNodesSurfingArguments.folder != null
        ? workGroupNodesSurfingArguments.folder.workGroupNodeId
        : null;
      await _copyMultipleFilesToSharedSpaceInteractor.execute(
          copyRequests: nodes.map((node) => node.toCopyRequest()).toList(),
          destinationSharedSpaceId: workGroupNodesSurfingArguments.sharedSpaceNodeNested.sharedSpaceId,
          destinationParentNodeId: parentNodeId)
        .then((result) => result.fold(
          (failure) {
            print('$failure');
            store.dispatch(SharedSpaceAction(Left(failure)));
          },
          (success) {
            print('$success');
            store.dispatch(SharedSpaceAction(Right(success)));
          }));
    });
  }

  void openMoreActionBottomMenu(BuildContext context, List<WorkGroupNode> workGroupNodes, List<Widget> actionTiles, Widget footerAction) {
    ContextMenuBuilder(context)
        .addHeader(MoreActionBottomSheetHeaderBuilder(
          context,
          Key('more_action_menu_header'),
          workGroupNodes.map<PresentationFile>((element)
          {
            if (element is WorkGroupFolder) {
              return WorkGroupFolderPresentationFile.fromWorkGroupFolder(element);
            } else {
              return WorkGroupDocumentPresentationFile.fromWorkGroupDocument(element);
            }
          }).toList()).build())
        .addTiles(actionTiles)
        .addFooter(footerAction)
        .build();
  }

  void previewWorkGroupDocument(BuildContext context, WorkGroupDocument workGroupDocument) {
    _appNavigation.popBack();
    final canPreviewDocument = Platform.isIOS ? workGroupDocument.mediaType.isIOSSupportedPreview() : workGroupDocument.mediaType.isAndroidSupportedPreview();
    if (canPreviewDocument || workGroupDocument.hasThumbnail) {
      final cancelToken = CancelToken();
      _showPrepareToPreviewFileDialog(context, workGroupDocument, cancelToken);

      var downloadPreviewType = DownloadPreviewType.original;
      if (workGroupDocument.mediaType.isImageFile()) {
        downloadPreviewType = DownloadPreviewType.image;
      } else if (!canPreviewDocument) {
        downloadPreviewType = DownloadPreviewType.thumbnail;
      }

      store.dispatch(_handleDownloadPreviewWorkGroupDocument(workGroupDocument, downloadPreviewType, cancelToken));
    }
  }

  OnlineThunkAction _handleDownloadPreviewWorkGroupDocument(
    WorkGroupDocument workGroupDocument,
    DownloadPreviewType downloadPreviewType,
    CancelToken cancelToken
  ) {
    return OnlineThunkAction((Store<AppState> store) async {
      await _downloadPreviewWorkGroupDocumentInteractor
        .execute(workGroupDocument, downloadPreviewType, cancelToken)
        .then((result) => result.fold(
            (failure) {
              if (failure is DownloadPreviewWorkGroupDocumentFailure && !(failure.downloadPreviewException is CancelDownloadFileException)) {
                store.dispatch(SharedSpaceAction(Left(NoWorkGroupDocumentPreviewAvailable())));
              }
            },
            (success) {
              if (success is DownloadPreviewWorkGroupDocumentViewState) {
                _openDownloadedPreviewWorkGroupDocument(workGroupDocument, success);
              }
        }));
    });
  }

  void _openDownloadedPreviewWorkGroupDocument(
    WorkGroupDocument workGroupDocument,
    DownloadPreviewWorkGroupDocumentViewState viewState
  ) async {
    _appNavigation.popBack();

    final openResult = await open_file.OpenFile.open(
      Uri.decodeFull(viewState.filePath.path),
      type: Platform.isAndroid ? workGroupDocument.mediaType.mimeType : null,
      uti:  Platform.isIOS ? workGroupDocument.mediaType.getDocumentUti().value : null);

    if (openResult.type != open_file.ResultType.done) {
      store.dispatch(SharedSpaceAction(Left(NoWorkGroupDocumentPreviewAvailable())));
    }
  }

  void _showPrepareToPreviewFileDialog(
    BuildContext context,
    WorkGroupDocument workGroupDocument,
    CancelToken cancelToken
  ) {
    showCupertinoDialog(
      context: context,
      builder: (_) => DownloadingFileBuilder(cancelToken, _appNavigation)
        .key(Key('prepare_to_preview_file_dialog'))
        .title(AppLocalizations.of(context).preparing_to_preview_file)
        .content(AppLocalizations.of(context).downloading_file(workGroupDocument.name))
        .actionText(AppLocalizations.of(context).cancel)
        .build());
  }

  void openPopupMenuSorter(BuildContext context, Sorter currentSorter) {
    ContextMenuBuilder(context)
        .addHeader(SimpleBottomSheetHeaderBuilder(Key('order_by_menu_header'))
            .addLabel(AppLocalizations.of(context).order_by)
            .build())
        .addTiles(OrderByDialogBottomSheetBuilder(context, currentSorter)
            .onSelectSorterAction((sorterSelected) => _sortFiles(sorterSelected))
            .build())
        .build();
  }

  void loadSorterAndAllChildNodes() async {
    _stateSubscription.add(currentState.copyWith(showLoading: true));

    final isRootFolder = currentState.folderNodeType == FolderNodeType.root;
    final defaultSorter = Sorter.fromOrderScreen(OrderScreen.sharedSpace);

    await Future.wait([
      _getSorterInteractor.execute(OrderScreen.sharedSpace),
      _getAllChildNodesInteractor.execute(isRootFolder ? currentState.sharedSpaceId : currentState.node.sharedSpaceId,
        parentId: isRootFolder ? null : currentState.node.workGroupNodeId,
      )
    ]).then((response) async {
      response[0].fold((failure) {
        _stateSubscription.add(currentState.copyWith(sorter: defaultSorter));
      }, (success) {
        _stateSubscription.add(currentState.copyWith(sorter: success is GetSorterSuccess ? success.sorter : defaultSorter));
      });
      response[1].fold(
        (failure) {
          _workGroupNodesList = [];
          _stateSubscription.add(currentState.copyWith(children: [], showLoading: false));
        },
        (success) {
          _workGroupNodesList = success is GetChildNodesViewState ? success.workGroupNodes : [];
          _stateSubscription.add(currentState.setWorkGroupNodesList(_workGroupNodesList, showLoading: false));
        },
      );
    });

    store.dispatch(_sortFilesAction(currentState.sorter));
  }

  ThunkAction<AppState> _sortFilesAction(Sorter sorter) {
    return (Store<AppState> store) async {
      await Future.wait([
        _saveSorterInteractor.execute(sorter),
        _sortInteractor.execute(_workGroupNodesList, sorter)
      ]).then((response) => response[1].fold((failure) {
        _workGroupNodesList = [];
        _stateSubscription.add(currentState.setWorkGroupNodesList(_workGroupNodesList, newSorter: sorter));
      }, (success) {
        _workGroupNodesList = success is GetChildNodesViewState ? success.workGroupNodes : [];
        _stateSubscription.add(currentState.setWorkGroupNodesList(_workGroupNodesList, newSorter: sorter));
      }));
    };
  }

  void _sortFiles(Sorter sorter) {
    final newSorter = currentState.sorter == sorter ? sorter.getSorterByOrderType(sorter.orderType) : sorter;
    _appNavigation.popBack();
    store.dispatch(_sortFilesAction(newSorter));
  }
}
