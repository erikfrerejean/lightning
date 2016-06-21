<?php

/**
 * @file
 * Enables defines the Lightning Profile install screen by modifying the install
 * form.
 */

use Drupal\Component\Serialization\Yaml;
use Drupal\Component\Utility\UrlHelper;
use Drupal\Core\Config\FileStorage;
use Drupal\Core\Config\InstallStorage;
use Drupal\Core\Form\FormStateInterface;

/**
 * Implements hook_install_tasks_alter().
 */
function lightning_install_tasks_alter(array &$tasks, array $install_state) {
  $tasks['install_finished']['function'] = 'lightning_post_install_redirect';
}

/**
 * Redirects the user to a particular URL after installation.
 *
 * @param array $install_state
 *   The current install state.
 */
function lightning_post_install_redirect(array $install_state) {
  $post_install = lightning_post_install_info();

  if (!empty($post_install['redirect'])) {
    $redirect = $post_install['redirect']['path'];

    if (!empty($post_install['redirect']['query'])) {
      $redirect .= '?' . UrlHelper::buildQuery($post_install['redirect']['query']);
    }
    install_goto($redirect);
  }
}

/**
 * Returns site-specific post-install configuration.
 *
 * @return array
 */
function lightning_post_install_info() {
  $path = \Drupal::service('site.path') . '/lightning.extend.yml';
  if (file_exists($path)) {
    $extend = file_get_contents($path);
    return Yaml::decode($extend);
  }
  else {
    return [];
  }
}

/**
 * Rebuilds the service container.
 */
function lightning_rebuild_container() {
  require_once \Drupal::root() . '/core/includes/utility.inc';
  $class_loader = \Drupal::service('class_loader');
  $request = \Drupal::request();
  drupal_rebuild($class_loader, $request);
}

/**
 * Implements template_preprocess_block().
 */
function lightning_preprocess_block(array &$variables) {
  $variables['attributes']['data-block-plugin-id'] = $variables['elements']['#plugin_id'];
}

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 *
 * Allows the profile to alter the site configuration form.
 */
function lightning_form_install_configure_form_alter(array &$form, FormStateInterface $form_state) {
  // Add a value as example that one can choose an arbitrary site name.
  $form['site_information']['site_name']['#placeholder'] = t('Lightning Demo');

  // Add 'Lightning' fieldset and options.
  $form['lightning'] = [
    '#type' => 'details',
    '#title' => t('Lightning Features'),
    '#weight' => -5,
    '#open' => TRUE,
  ];

  // Checkboxes to enable Lightning Features.
  $form['lightning']['extensions'] = [
    '#type' => 'checkboxes',
    '#title' => t('Enable Extensions'),
    '#description' => t('You can choose to disable some of Lightning\'s functionality above. However, it is not recommended.'),
    '#options' => [
      'lightning_media' => 'Lightning Media',
      'lightning_layout' => 'Lightning Layout',
      'lightning_workflow' => 'Lightning Workflow',
    ],
  ];
  // All our extensions are checked by default.
  $form['lightning']['extensions']['#default_value'] = array_keys($form['lightning']['extensions']['#options']);

  $form['#submit'][] = 'lightning_extensions_enable';
}

/**
 * Enable requested Lightning extensions and demo content.
 */
function lightning_extensions_enable($form_id, FormStateInterface $form_state) {
  $features = array_filter($form_state->getValue('extensions'));
  if ($features) {
    if (in_array('lightning_media', $features)) {
      $features = array_merge($features, [
        'lightning_media_document',
        'lightning_media_image',
        'lightning_media_instagram',
        'lightning_media_twitter',
        'lightning_media_video',
      ]);
    }
    \Drupal::service('module_installer')->install($features);
  }

  $post_install = lightning_post_install_info();
  if (!empty($post_install['modules'])) {
    \Drupal::service('module_installer')->install($post_install['modules']);
  }
}

/**
 * Reads a stored config file from a module's config/install directory.
 *
 * @param string $id
 *   The config ID.
 * @param string $module
 *   (optional) The module to search. Defaults to 'lightning' (not technically
 *   a module, but profiles are treated like modules by the install system).
 *
 * @return array
 *   The config data.
 */
function lightning_read_config($id, $module = 'lightning') {
  // Statically cache all FileStorage objects, keyed by module.
  static $storage = [];

  if (empty($storage[$module])) {
    $dir = \Drupal::service('module_handler')->getModule($module)->getPath();
    $storage[$module] = new FileStorage($dir . '/' . InstallStorage::CONFIG_INSTALL_DIRECTORY);
  }
  return $storage[$module]->read($id);
}
